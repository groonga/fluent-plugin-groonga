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
    config_param :bind, :string, :default => "0.0.0.0"
    config_param :port, :integer, :default => 10041
    config_param :real_host, :string
    config_param :real_port, :integer, :default => 10041

    def configure(conf)
      super
      repeater_factory = RepeaterFactory.new(@real_host, @real_port)
      case @protocol
      when "http"
        @input = HTTPInput.new(@bind, @port, repeater_factory)
      when "gqtp"
        @input = GQTPInput.new(@bind, @port, repeater_factory)
      else
        message = "unknown protocol: <#{@protocol.inspect}>"
        $log.error message
        raise ConfigError, message
      end
    end

    def start
      @input.start
    end

    def shutdown
      @input.shutdown
    end

    class RepeaterFactory
      def initialize(host, port)
        @host = host
        @port = port
      end

      def connect(client)
        Repeater.connect(@host, @port, client)
      end
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

    class HTTPInput
      include DetachMultiProcessMixin

      def initialize(bind, port, repeater_factory)
        @bind = bind
        @port = port
        @repeater_factory = repeater_factory
      end

      def start
        listen_socket = TCPServer.new(@bind, @port)
        detach_multi_process do
          @loop = Coolio::Loop.new

          @socket = Coolio::TCPServer.new(listen_socket, nil, Handler, self)
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
        repeater = @repeater_factory.connect(client)
        repeater.attach(@loop)
        repeater
      end

      private
      def run
        @loop.run
      rescue
        $log.error "unexpected error", :error => $!.to_s
        $log.error_backtrace
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
            process(command, params, @body)
          end
        end

        private
        def process(command, params, body)
          case command
          when "load"
            params["data"] = body
            Engine.emit("groonga.command.#{command}", Engine.now, params)
          else
            Engine.emit("groonga.command.#{command}", Engine.now, params)
          end
        end
      end
    end
  end
end
