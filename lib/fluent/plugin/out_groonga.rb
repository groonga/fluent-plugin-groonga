# -*- coding: utf-8 -*-
#
# Copyright (C) 2012-2014  Kouhei Sutou <kou@clear-code.com>
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

require "yajl"

require "groonga/client"

module Fluent
  class GroongaOutput < BufferedOutput
    Plugin.register_output("groonga", self)

    def initialize
      super
    end

    config_param :protocol, :default => :http do |value|
      case value
      when "http", "gqtp", "command"
        value.to_sym
      else
        raise ConfigError, "must be http, gqtp or command: <#{value}>"
      end
    end
    config_param :table, :string, :default => nil

    def configure(conf)
      super
      @client = create_client(@protocol)
      @client.configure(conf)

      @emitter = Emitter.new(@client, @table)
    end

    def start
      super
      @client.start
    end

    def shutdown
      super
      @client.shutdown
    end

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    def write(chunk)
      @emitter.emit(chunk)
    end

    private
    def create_client(protocol)
      case protocol
      when :http, :gqtp
        NetworkClient.new(protocol)
      when :command
        CommandClient.new
      end
    end

    class Emitter
      def initialize(client, table)
        @client = client
        @table = table
      end

      def emit(chunk)
        records = []
        chunk.msgpack_each do |message|
          tag, _, record = message
          if /\Agroonga\.command\./ =~ tag
            name = $POSTMATCH
            unless records.empty?
              store_records(records)
              records.clear
            end
            @client.send(name, record)
          else
            records << record
          end
        end
        store_records(records) unless records.empty?
      end

      private
      def send_command(name, arguments)
        command_class = Groonga::Command.find(name)
        command = command_class.new(name, arguments)
        @client.send(command)
      end

      def store_records(records)
        return if @table.nil?

        arguments = {
          "table" => @table,
          "values" => Yajl::Encoder.encode(records),
        }
        send_command("load", arguments)
      end
    end

    class NetworkClient
      include Configurable

      config_param :host, :string, :default => nil
      config_param :port, :integer, :default => nil

      def initialize(protocol)
        super()
        @protocol = protocol
      end

      def start
        @client = nil
      end

      def shutdown
        return if @client.nil?
        @client.close
      end

      def send(command)
        @client ||= Groonga::Client.new(:protocol => @protocol,
                                        :host     => @host,
                                        :port     => @port,
                                        :backend  => :synchronous)
        @client.execute(command)
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
      end

      def shutdown
        @input.close
        read_output("shutdown")
        @output.close
        @error.close
        Process.waitpid(@pid)
      end

      def send(command)
        body = nil
        if command.name == "load"
          body = command.arguments.delete(:values)
        end
        uri = command.to_uri_format
        @input.write("#{uri}\n")
        if body
          body.each_line do |line|
            @input.write("#{line}\n")
          end
        end
        @input.flush
        read_output(uri)
      end

      private
      def run_groonga
        env = {}
        input = IO.pipe("ASCII-8BIT")
        output = IO.pipe("ASCII-8BIT")
        error = IO.pipe("ASCII-8BIT")
        input_fd = input[0].to_i
        output_fd = output[1].to_i
        options = {
          input_fd => input_fd,
          output_fd => output_fd,
          :err => error[1],
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
        input[0].close
        @input = input[1]
        output[1].close
        @output = output[0]
        error[1].close
        @error = error[0]
      end

      def read_output(context)
        output_message = ""
        error_message = ""

        loop do
          readables = IO.select([@output, @error], nil, nil, 0)
          break if readables.nil?

          readables.each do |readable|
            case readable
            when @output
              output_message << @output.gets
            when @error
              error_message << @error.gets
            end
          end
        end

        unless output_message.empty?
          Engine.log.debug("[output][groonga][output]",
                           :context => context,
                           :message => output_message)
        end
        unless error_message.empty?
          Engine.log.error("[output][groonga][error]",
                           :context => context,
                           :message => error_message)
        end
      end
    end
  end
end
