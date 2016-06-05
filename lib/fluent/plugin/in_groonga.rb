# -*- coding: utf-8 -*-
#
# Copyright (C) 2012-2016  Kouhei Sutou <kou@clear-code.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License version 2.1 as published by the Free Software Foundation.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

require "English"
require "uri"
require "webrick/httputils"

require "http_parser"

require "gqtp"
require "groonga/command/parser"

require "fluent/input"
require "fluent/process"

module Fluent
  class GroongaInput < Input
    Plugin.register_input("groonga", self)

    def initialize
      super
    end

    config_param :protocol, :defalut => :http do |value|
      case value
      when "http", "gqtp"
        value.to_sym
      else
        raise ConfigError, "must be http or gqtp: <#{value}>"
      end
    end

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
      @input.start
    end

    def shutdown
      @input.shutdown
    end

    class Repeater < Coolio::TCPSocket
      def initialize(socket, handler)
        super(socket)
        @handler = handler
      end

      def on_read(data)
        @handler.write(data)
      end

      def on_close
        @handler.close
      end
    end

    class BaseInput
      include Configurable
      include DetachMultiProcessMixin

      config_param :bind, :string, :default => "0.0.0.0"
      config_param :port, :integer, :default => nil
      config_param :real_host, :string
      config_param :real_port, :integer, :default => nil
      DEFAULT_EMIT_COMMANDS = [
        /\Atable_/,
        /\Acolumn_/,
        "delete",
        /\Aplugin_/,
        "register",
        "truncate",
        "load",
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

      def start
        listen_socket = TCPServer.new(@bind, @port)
        detach_multi_process do
          @loop = Coolio::Loop.new

          @socket = Coolio::TCPServer.new(listen_socket, nil,
                                          handler_class, self)
          @loop.attach(@socket)

          @shutdown_notifier = Coolio::AsyncWatcher.new
          @loop.attach(@shutdown_notifier)

          @thread = Thread.new do
            run
          end
        end
      end

      def shutdown
        @loop.stop
        @socket.close
        @shutdown_notifier.signal
        @thread.join
      end

      def create_repeater(client)
        repeater = Repeater.connect(@real_host, @real_port, client)
        repeater.attach(@loop)
        repeater
      end

      def emit(command, params)
        return unless emit_command?(command)
        @input_plugin.router.emit("groonga.command.#{command}",
                                  Engine.now,
                                  params)
      end

      private
      def run
        @loop.run
      rescue
        $log.error "unexpected error", :error => $!.to_s
        $log.error_backtrace
      end

      def emit_command?(command)
        return true if @emit_commands.empty?
        @emit_commands.any? do |pattern|
          pattern === command
        end
      end
    end

    class HTTPInput < BaseInput
      private
      def default_port
        10041
      end

      def handler_class
        Handler
      end

      class Handler < Coolio::Socket
        def initialize(socket, input)
          super(socket)
          @input = input
        end

        def on_connect
          @parser = HTTP::Parser.new(self)
          @repeater = @input.create_repeater(self)
        end

        def on_read(data)
          begin
            @parser << data
          rescue HTTP::Parser::Error
            $log.error("[input][groonga][error] " +
                       "failed to parse HTTP request:",
                       :error => $!.to_s)
            $log.error_backtrace
            close
          end
        end

        def on_message_begin
          @body = ""
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
            @input.emit(command, params)
          end
        end
      end
    end

    class GQTPInput < BaseInput
      private
      def default_port
        10043
      end

      def handler_class
        Handler
      end

      class Handler < Coolio::Socket
        def initialize(socket, input)
          super(socket)
          @input = input
        end

        def on_connect
          @parser = Parser.new(@input)
          @repeater = @input.create_repeater(self)
        end

        def on_read(data)
          @parser << data
          @repeater.write(data)
        end

        def on_close
          @parser.close
        end
      end

      class Parser < GQTP::Parser
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
            @input.emit(command.name, command.arguments)
          end
          @command_parser.on_load_value do |command, value|
            arguments = command.arguments.dup
            arguments[:columns] = command.columns.join(", ")
            arguments[:values] = Yajl::Encoder.encode([value])
            @input.emit(command.name, arguments)
          end
        end
      end
    end
  end
end
