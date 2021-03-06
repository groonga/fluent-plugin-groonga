# Copyright (C) 2012-2018  Kouhei Sutou <kou@clear-code.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

require "English"
require "uri"
require "webrick/httputils"

require "http_parser"

require "gqtp"
require "groonga/command/parser"

require "fluent/plugin/input"

module Fluent
  module Plugin
    class GroongaInput < Input
      Plugin.register_input("groonga", self)

      helpers :server

      def initialize
        super
      end

      config_param :protocol, :enum, :list => [:http, :gqtp], :default => :http
      config_param :command_name_position, :enum, :list => [:tag, :record], :default => :tag

      def configure(conf)
        super
        case @protocol
        when :http
          @input = HTTPInput.new(self)
        when :gqtp
          @input = GQTPInput.new(self)
        end
        @input.configure(conf)
      end

      def start
        super

        port = @input.port
        bind = @input.bind
        log.info("[input][groonga][connect] listening port",
                 :port => port, :bind => bind)
        server_create_connection(:groonga_input,
                                 port,
                                 :proto => :tcp,
                                 :shared => system_config.workers > 1,
                                 :bind => bind) do |connection|
          handler = nil
          real_host = @input.real_host
          real_port = @input.real_port
          repeater = Coolio::TCPSocket.connect(real_host, real_port)
          repeater.on_connect_failed do
            log.error("[input][groonga][connect][error] " +
                      "failed to connect to Groonga:",
                      :real_host => real_host,
                      :real_port => real_port)
            connection.close
          end
          repeater.on_read do |data|
            handler.write_back(data)
          end
          repeater.on_close do
            connection.on(:write_complete) do
              handler.close
            end
          end
          event_loop_attach(repeater)

          handler = @input.create_handler(connection, repeater)
          connection.data do |data|
            handler.on_read(data)
          end
        end
      end

      def shutdown
        super
      end

      def multi_workers_ready?
        true
      end

      class BaseInput
        include Configurable

        config_param :bind, :string, :default => "0.0.0.0"
        config_param :port, :integer, :default => nil
        config_param :real_host, :string
        config_param :real_port, :integer, :default => nil
        DEFAULT_EMIT_COMMANDS = [
          "clearlock",
          "column_copy",
          "column_create",
          "column_remove",
          "column_rename",
          "config_delete",
          "config_set",
          "delete",
          "load",
          "lock_acquire",
          "lock_clear",
          "lock_release",
          "logical_table_remove",
          "object_remove",
          "plugin_register",
          "plugin_unregister",
          "register",
          "reindex",
          "table_copy",
          "table_create",
          "table_remove",
          "table_rename",
          "truncate",
        ]
        config_param :emit_commands, :default => DEFAULT_EMIT_COMMANDS do |value|
          commands = value.split(/\s*,\s*/)
          commands.collect do |command|
            if /\A\/(.*)\/(i)?\z/ =~ command
              pattern = $1
              flag_mark = $2
              flag = 0
              flag |= Regexp::IGNORECASE if flag_mark == "i"
              Regexp.new(pattern, flag)
            else
              command
            end
          end
        end

        def initialize(input_plugin)
          @input_plugin = input_plugin
        end

        def configure(conf)
          super

          @port ||= default_port
          @real_port ||= default_port
        end

        def emit(command, params)
          normalized_command = command.split(".")[0]
          return unless emit_command?(normalized_command)
          case @input_plugin.command_name_position
          when :tag
            tag = "groonga.command.#{normalized_command}"
            record = params
          else
            tag = "groonga.command"
            record = {
              "name" => normalized_command,
              "arguments" => params
            }
          end
          @input_plugin.router.emit(tag,
                                    Engine.now,
                                    record)
        end

        def log
          @input_plugin.log
        end

        private
        def emit_command?(command)
          return true if @emit_commands.empty?
          @emit_commands.any? do |pattern|
            pattern === command
          end
        end
      end

      class HTTPInput < BaseInput
        def create_handler(connection, repeater)
          Handler.new(self, connection, repeater)
        end

        private
        def default_port
          10041
        end

        class Handler
          def initialize(input, connection, repeater)
            @input = input
            @connection = connection
            @repeater = repeater
            @request_handler = RequestHandler.new(@input, @repeater)
            @response_handler = ResponseHandler.new(self, @input)
          end

          def on_read(data)
            begin
              @request_handler << data
            rescue HTTP::Parser::Error, URI::InvalidURIError
              @input.log.error("[input][groonga][request][error] " +
                               "failed to parse HTTP request:",
                               :error => "#{$!.class}: #{$!}")
              @input.log.error_backtrace
              reply_error_response("400 Bad Request")
            rescue
              @input.log.error("[input][groonga][request][error] " +
                               "failed to handle HTTP request:",
                               :error => "#{$!.class}: #{$!}")
              @input.log.error_backtrace
              reply_error_response("500 Internal Server Error")
            end
          end

          def write_back(data)
            begin
              @response_handler << data
            rescue
              @input.log.error("[input][groonga][response][error] " +
                               "failed to handle HTTP response from Groonga:",
                               :error => "#{$!.class}: #{$!}")
              @input.log.error_backtrace
              reply_error_response("500 Internal Server Error")
              return
            end
            @connection.write(data)
          end

          def on_response_complete(response)
            if need_emit?(response)
              @input.emit(@request_handler.command,
                          @request_handler.params)
            end
            @connection.on(:write_complete) do
              @repeater.close
            end
          end

          def close
            @connection.close
          end

          private
          def need_emit?(response)
            case @request_handler.command
            when "load", "object_remove"
              return true
            end

            case response
            when Array
              return_code = response[0][0]
              return_code.zero?
            else
              false
            end
          end

          def reply_error_response(status)
            @connection.write("HTTP1.1 #{status}\r\n")
            @connection.write("Server: fluent-plugin-groonga\r\n")
            @connection.write("Connection: close\r\n")
            @connection.write("Content-Length: 0\r\n")
            @connection.write("\r\n")
            @connection.on(:write_complete) do
              @repeater.close
            end
          end
        end

        class RequestHandler
          attr_reader :command
          attr_reader :params
          def initialize(input, repeater)
            @input = input
            @repeater = repeater
            @parser = Http::Parser.new(self)
          end

          def <<(chunk)
            @parser << chunk
          end

          def on_message_begin
            @body = ""
            @command = nil
            @params = nil
          end

          def on_headers_complete(headers)
            method = @parser.http_method
            url = @parser.request_url
            http_version = @parser.http_version.join(".")
            @repeater.write("#{method} #{url} HTTP/#{http_version}\r\n")
            headers.each do |name, value|
              case name
              when /\AHost\z/i
                real_host = @input.real_host
                real_port = @input.real_port
                @repeater.write("#{name}: #{real_host}:#{real_port}\r\n")
              else
                @repeater.write("#{name}: #{value}\r\n")
              end
            end
            @repeater.write("\r\n")
          end

          def on_body(chunk)
            @body << chunk
            @repeater.write(chunk)
          end

          def on_message_complete
            uri = URI.parse(@parser.request_url)
            params = WEBrick::HTTPUtils.parse_query(uri.query)
            path_info = uri.path
            case path_info
            when /\A\/d\//
              command = $POSTMATCH
              if command == "load"
                params["values"] = @body unless @body.empty?
              end
              @command = command
              @params = params
            end
          end
        end

        class ResponseHandler
          def initialize(handler, input)
            @handler = handler
            @input = input
            @parser = Http::Parser.new(self)
          end

          def <<(chunk)
            @parser << chunk
          end

          def on_message_begin
            @body = ""
            @content_type = nil
          end

          def on_headers_complete(headers)
            headers.each do |name, value|
              case name
              when /\AContent-Type\z/i
                @content_type = value
              end
            end
          end

          def on_body(chunk)
            @body << chunk
          end

          def on_message_complete
            return if @parser.status_code == 100

            response = nil
            case @content_type
            when /\Aapplication\/json\z/i
              begin
                response = JSON.parse(@body)
              rescue JSON::ParserError
                @input.log.warn("[input][groonga][response][warn] " +
                                "failed to parse response JSON:",
                                :error => "#{$!.class}: #{$!}",
                                :json => @body)
              end
            when /\Aapplication\/x-msgpack\z/i
              begin
                response = MessagePack.unpack(@body)
              rescue MessagePack::UnpackError, EOFError
                @input.log.warn("[input][groonga][response][warn] " +
                                "failed to parse response MessagePack",
                                :error => "#{$!.class}: #{$!}",
                                :msgpack => @body)
              end
            when /\Atext\/x-groonga-command-list\z/i
              response = @body
            end
            @handler.on_response_complete(response)
          end
        end
      end

      class GQTPInput < BaseInput
        def create_handler(connection, repeater)
          Handler.new(self, connection, repeater)
        end

        private
        def default_port
          10043
        end

        class Handler
          def initialize(input, connection, repeater)
            @input = input
            @connection = connection
            @repeater = repeater

            @request_parser = RequestParser.new(@input)
          end

          def on_read(data)
            @request_parser << data
            @repeater.write(data)
          end

          def write_back(data)
            @connection.write(data)
          end

          def close
            @request_parser.close
            @connection.close
          end
        end

        class RequestParser < GQTP::Parser
          def initialize(input)
            super()
            @input = input
            initialize_command_parser
          end

          def on_body(chunk)
            @command_parser << chunk
          end

          def on_complete
            @command_parser << "\n"
          end

          def close
            @command_parser.finish
          end

          private
          def initialize_command_parser
            @command_parser = Groonga::Command::Parser.new
            @command_parser.on_command do |command|
              @input.emit(command.command_name, command.arguments)
            end
            @command_parser.on_load_value do |command, value|
              arguments = command.arguments.dup
              arguments[:columns] = command.columns.join(", ")
              arguments[:values] = Yajl::Encoder.encode([value])
              @input.emit(command.command_name, arguments)
            end
          end
        end
      end
    end
  end
end
