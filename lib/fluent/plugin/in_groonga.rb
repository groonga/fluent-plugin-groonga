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

require "fluent/plugin/in_http"

module Fluent
  class GroongaInput < HttpInput
    Plugin.register_input("groonga", self)

    def initialize
      super
    end

    config_param :protocol, :string, :default => "http"
    config_param :port, :integer, :default => 10041

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
      @input.configure({"port" => @port}.merge(conf))
    end

    def start
      @input.start
    end

    def shutdown
      @input.shutdown
    end

    class HTTPInput < HttpInput
      def on_request(path_info, params)
        case path_info
        when /\A\/d\/([a-zA-Z0-9\-_]+)\z/
          command = $1
          process(command, params)
          ["200 OK", {}, ""]
        else
          ["404 Not Found", {}, ""]
        end
      end

      private
      def process(command, params)
        case command
        when "load"
          params = params.dup
          json = params.delete("json")
          params["data"] = json
          Engine.emit("groonga.command.#{command}", Engine.now, params)
        else
          Engine.emit("groonga.command.#{command}", Engine.now, params)
        end
      end
    end
  end
end
