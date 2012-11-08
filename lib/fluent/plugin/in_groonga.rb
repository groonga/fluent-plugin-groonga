# -*- coding: utf-8 -*-
#
# Copyright (C) 2012  Kouhei Sutou <kou@clear-code.com>
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
require "webrick/httputils"

require "http_parser"

module Fluent
  class GroongaInput < Input
    Plugin.register_input("groonga", self)

    def initialize
      super
    end

    config_param :protocol, :string, :default => "http"

    def configure(conf)
      super
      case @protocol
      when "http"
        @input = HTTPInput.new
      when "gqtp"
        @input = GQTPInput.new
      else
        message = "unknown protocol: <#{@protocol.inspect}>"
        $log.error message
        raise ConfigError, message
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
      config_param :port, :integer, :default => 10041
      config_param :real_host, :string
      config_param :real_port, :integer, :default => 10041
      DEFAULT_EMIT_COMMANDS = [
        /\Atable_/,
        /\Acolumn_/,
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

      def emit(command, params, body)
        return unless emit_command?(command)
        case command
        when "load"
          params["data"] = body
          Engine.emit("groonga.command.#{command}", Engine.now, params)
        else
          Engine.emit("groonga.command.#{command}", Engine.now, params)
        end
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
          @parser << data
          @repeater.write(data)
        end

        def on_message_begin
          @body = ""
        end

        def on_headers_complete(headers)
        end

        def on_body(chunk)
          @body << chunk
        end

        def on_message_complete
          params = WEBrick::HTTPUtils.parse_query(@parser.query_string)
          path_info = @parser.request_path
          case path_info
          when /\A\/d\//
            command = $POSTMATCH
            @input.emit(command, params, @body)
          end
        end
      end
    end
  end
end
