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

require "fileutils"
require "cgi/util"

module Fluent
  class GroongaOutput < ObjectBufferedOutput
    Plugin.register_output("groonga", self)

    def initialize
      super
    end

    config_param :protocol, :string, :default => "http"

    def configure(conf)
      super
      case @protocol
      when "http"
        @client = HTTPClient.new
      when "gqtp"
        @client = GQTPClient.new
      when "command"
        @client = CommandClient.new
      end
      @client.configure(conf)
    end

    def start
      super
      @client.start
    end

    def shutdown
      super
      @client.shutdown
    end

    def write_objects(tag, chunk)
      command = tag.split(/\./)[2]
      chunk.each do |time, parameters|
        @client.send(command, parameters)
      end
    end

    class HTTPClient
      include Configurable

      config_param :host, :string, :default => "localhost"
      config_param :port, :integer, :default => 10041
    end

    class GQTPClient
      include Configurable

      config_param :host, :string, :default => "localhost"
      config_param :port, :integer, :default => 10041
    end

    class CommandClient
      include Configurable

      config_param :groonga, :string, :default => "groonga"
      config_param :database, :string, :default => nil

      def initialize
        super
      end

      def configure(conf)
        super
      end

      def start
        env = {}
        @input = IO.pipe("ASCII-8BIT")
        @output = IO.pipe("ASCII-8BIT")
        @error = IO.pipe("ASCII-8BIT")
        input_fd = @input[0].to_i
        output_fd = @output[1].to_i
        options = {
          input_fd => input_fd,
          output_fd => output_fd,
          :err => @error[1],
        }
        arguments = [
          "--log-path", "/tmp/groonga.log",
          "--input-fd", input_fd.to_s,
          "--output-fd", output_fd.to_s,
        ]
        unless File.exist?(@database)
          FileUtils.mkdir_p(File.dirname(@database))
          arguments << "-n"
        end
        arguments << @database
        @pid = spawn(env, @groonga, *arguments, options)
        @input[0].close
        @output[1].close
        @error[1].close
      end

      def shutdown
        @input[1].close
        @output[0].close
        @error[0].close
        Process.waitpid(@pid)
      end

      def send(command, parameters={})
        body = nil
        if command == "load"
          body = parameters.delete("data")
        end
        url_encoded_parameters = parameters.collect do |key, value|
          "#{CGI.escape(key)}=#{CGI.escape(value)}"
        end
        path = "/d/#{command}"
        unless url_encoded_parameters.empty?
          path << "?#{url_encoded_parameters.join('&')}"
        end
        p path
        @input[1].write("#{path}\n")
        if body
          body.each_line do |line|
            @input[1].write("#{line}\n")
          end
        end
        @input[1].flush
        p @output[0].gets
      end
    end
  end
end
