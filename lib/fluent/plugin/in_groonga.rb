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

require "webrick/config"
require "webrick/httprequest"
require "webrick/httpresponse"

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
    config_param :proxy_protocol, :string, :default => nil
    config_param :proxy_host, :string, :default => nil
    config_param :proxy_port, :integer, :default => 10041

    def configure(conf)
      super
      @proxy_factory = ProxyFactory.new(@proxy_protocol, @proxy_host, @proxy_port)
      case @protocol
      when "http"
        @input = HTTPInput.new(@bind, @port, @proxy_factory)
      when "gqtp"
        @input = GQTPInput.new(@bind, @port, @proxy_factory)
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

    class ProxyFactory
      def initialize(protocol, host, port)
        @protocol = protocol
        @host = host
        @port = port
      end

      def connect(client)
        case @protocol
        when "http"
          HTTPGroongaProxy.connect(@host, @port, client)
        else
          nil
        end
      end
    end

    class HTTPInput
      include DetachMultiProcessMixin

      def initialize(bind, port, proxy_factory)
        @bind = bind
        @port = port
        @proxy_factory = proxy_factory
      end

      def start
        listen_socket = TCPServer.new(@bind, @port)
        detach_multi_process do
          @loop = Coolio::Loop.new

          @socket = Coolio::TCPServer.new(listen_socket, nil,
                                          Handler, @loop, @proxy_factory)
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

      private
      def run
        @loop.run
      rescue
        $log.error "unexpected error", :error => $!.to_s
        $log.error_backtrace
      end

      class Handler < Coolio::Socket
        class << self
          @@response_config = nil
          def response_config
            @@response_config ||= WEBrick::Config::HTTP.dup.update(
              :Logger => $log
            )
          end
        end

        def initialize(socket, loop, proxy_factory)
          super(socket)
          @loop = loop
          @proxy_factory = proxy_factory
          @completed = false
        end

        alias_method :<<, :write

        def on_connect
          @parser = HTTP::Parser.new(self)
          @proxy = @proxy_factory.connect(self)
          if @proxy
            @proxy.attach(@loop)
            @response = nil
          else
            @response = WEBrick::HTTPResponse.new(self.class.response_config)
          end
        end

        def on_read(data)
          @parser << data
          @proxy.write(data) if @proxy
        end

        def on_write_complete
          return unless @completed
          if @response
            close
          end
        end

        def on_message_begin
          @body = ""
        end

        def on_headers_complete(headers)
          expect = nil
          headers.each do |name, value|
            case name.downcase
            when "content-type"
              @content_type = value
            end
          end
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
          else
            if @response
              @response.status = "404"
            end
          end
          if @response
            @response["connection"] = "close"
            @response.send_response(self)
          end
          @completed = true
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

    class HTTPGroongaProxy < Coolio::TCPSocket
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
  end
end
