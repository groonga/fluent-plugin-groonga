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

module Fluent
  class GroongaOutput < Output
    Plugin.register_output("groonga", self)

    def initialize
      super
    end

    BufferedOutput.config_params.each do |name, (block, options)|
      if options[:type]
        config_param(name, options[:type], options)
      else
        config_param(name, options, &block)
      end
    end

    config_param :protocol, :string, :default => "http"
    config_param :table, :string, :default => nil

    def configure(conf)
      super
      @client = create_client(@protocol)
      @client.configure(conf)

      @emitter = Emitter.new(@client, @table)
      @output = create_output(@buffer_type, @emitter)
      @output.configure(conf)
    end

    def start
      super
      @client.start
      @output.start
    end

    def shutdown
      super
      @output.shutdown
      @client.shutdown
    end

    def emit(tag, event_stream, chain)
      @output.emit(tag, event_stream, chain)
    end

    def create_client(protocol)
      case protocol
      when "http"
        HTTPClient.new
      when "gqtp"
        GQTPClient.new
      when "command"
        CommandClient.new
      end
    end

    def create_output(buffer_type, emitter)
      if buffer_type == "none"
        RawGroongaOutput.new(emitter)
      else
        BufferedGroongaOutput.new(emitter)
      end
    end

    class Emitter
      def initialize(client, table)
        @client = client
        @table = table
      end

      def emit(tag, record)
        if /\Agroonga\.command\./ =~ tag
          name = $POSTMATCH
          send_command(name, record)
        else
          store_chunk(data)
        end
      end

      private
      def send_command(name, arguments)
        command_class = Groonga::Command.find(name)
        command = command_class.new(name, arguments)
        @client.send(command)
      end

      def store_chunk(value)
        return if @table.nil?

        values = [value]
        arguments = {
          "table" => @table,
          "values" => Yajl::Enocder.encode(values),
        }
        send_command("load", arguments)
      end
    end

    class RawGroongaOutput < Output
      def initialize(emitter)
        @emitter = emitter
        super()
      end

      def emit(tag, event_stream, chain)
        event_stream.each do |time, record|
          @emitter.emit(tag, record)
        end
        chain.next
      end
    end

    class BufferedGroongaOutput < BufferedOutput
      def initialize(emitter)
        @emitter = emitter
        super()
      end

      def format(tag, time, record)
        [tag, time, record].to_msgpack
      end

      def write(chunk)
        chunk.msgpack_each do |tag, time, record|
          @emitter.emit(tag, record)
        end
      end
    end

    class HTTPClient
      include Configurable

      config_param :host, :string, :default => nil
      config_param :port, :integer, :default => nil

      def start
        @loop = Coolio::Loop.new
      end

      def shutdown
      end

      def send(command)
        client = GroongaHTTPClient.connect(@host, @port)
        client.request("GET", command.to_uri_format)
        @loop.attach(client)
        @loop.run
      end

      class GroongaHTTPClient < Coolio::HttpClient
        def on_body_data(data)
        end
      end
    end

    class GQTPClient
      include Configurable

      config_param :host, :string, :default => nil
      config_param :port, :integer, :default => nil

      def start
        @loop = Coolio::Loop.new
        @client = nil
      end

      def shutdown
        return if @client.nil?
        @client.close do
          @loop.stop
        end
        @loop.run
      end

      def send(command)
        @client ||= GQTP::Client.new(:address => @host,
                                     :port => @port,
                                     :connection => :coolio,
                                     :loop => @loop)
        @client.send(command.to_command_format) do |header, body|
          @loop.stop
        end
        @loop.run
      end
    end

    class CommandClient
      include Configurable

      config_param :groonga, :string, :default => "groonga"
      config_param :database, :string
      config_param :arguments, :default => [] do |value|
        Shellwords.split(value)
      end

      def initialize
        super
      end

      def configure(conf)
        super
      end

      def start
        run_groonga
        wrap_io
      end

      def shutdown
        @groonga_input.close
        @groonga_output.close
        @groonga_error.close
        Process.waitpid(@pid)
      end

      def send(command)
        body = nil
        if command.name == "load"
          body = command.arguments.delete(:values)
        end
        @groonga_input.write("#{command.to_uri_format}\n")
        if body
          body.each_line do |line|
            @groonga_input.write("#{line}\n")
          end
        end
        @loop.run
      end

      private
      def run_groonga
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
        arguments = @arguments
        arguments += [
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

      def wrap_io
        @loop = Coolio::Loop.new

        @groonga_input = Coolio::IO.new(@input[1])
        on_write_complete = lambda do
          @loop.stop
        end
        @groonga_input.on_write_complete do
          on_write_complete.call
        end
        @groonga_output = Coolio::IO.new(@output[0])
        @groonga_error = Coolio::IO.new(@error[0])

        @loop.attach(@groonga_input)
        @loop.attach(@groonga_output)
        @loop.attach(@groonga_error)
      end
    end
  end
end
