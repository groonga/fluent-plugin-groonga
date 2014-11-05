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

    # alias is just for backward compatibility
    config_param :store_table, :string, :default => nil, :alias => :table

    config_section :table,
                   :param_name => "tables",
                   :required => false,
                   :multi => true do
      config_param :name, :string
      config_param :flags, :string, :default => nil
      config_param :key_type, :string, :default => nil
      config_param :default_tokenizer, :string, :default => nil
      config_param :token_filters, :string, :default => nil
      config_param :normalizer, :string, :default => nil
      config_section :index,
                     :param_name => "indexes",
                     :required => false,
                     :multi => true do
        config_param :name, :string
        config_param :source_table, :string
        config_param :source_columns, :string
      end
    end

    config_section :mapping,
                   :param_name => "mappings",
                   :required => false,
                   :multi => true do
      config_param :name, :string
      config_param :type, :string, :default => nil
      config_section :index,
                     :param_name => "indexes",
                     :required => false,
                     :multi => true do
        config_param :table, :string
        config_param :name, :string
        config_param :flags, :string, :default => nil
      end
    end

    def configure(conf)
      super
      @client = create_client(@protocol)
      @client.configure(conf)

      @emitter = Emitter.new(@client, @store_table)

      @tables = @tables.collect do |table|
        TableDefinition.new(table)
      end
    end

    def start
      super
      @client.start
      @emitter.start
      tables_creator = TablesCreator.new(@client, @tables)
      tables_creator.create
    end

    def shutdown
      super
      @emitter.shutdown
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

    class TableDefinition
      def initialize(raw)
        @raw = raw
      end

      def name
        @raw[:name]
      end

      def flags
        parse_flags(@raw[:flags] || "TABLE_NO_KEY")
      end

      def key_type
        @raw[:key_type]
      end

      def default_tokenizer
        @raw[:default_tokenizer]
      end

      def token_filters
        parse_items(@raw[:token_filters] || "")
      end

      def normalizer
        @raw[:normalizer]
      end

      def indexes
        (@raw[:indexes] || []).collect do |raw|
          IndexDefinition.new(self, raw)
        end
      end

      def use_n_gram_tokenizer?
        /\AToken(?:Uni|Bi|Tri)gram/ === default_tokenizer.to_s
      end

      def have_difference?(table)
        return true if table.name != name

        table_flags = (parse_flags(table.flags) - ["PERSISTENT"])
        return true if table_flags.sort != flags.sort

        return true if table.domain != key_type

        return true if table.default_tokenizer != default_tokenizer

        # TODO
        # return true if table.token_filters.sort != token_filters.sort

        return true if table.normalizer != normalizer

        false
      end

      def to_create_arguments
        arguments = {
          "name" => name,
          "flags" => flags.join("|"),
          "key_type" => key_type,
          "default_tokenizer" => default_tokenizer,
          # TODO
          # "token_filters" => token_filters.join("|"),
          "normalizer" => normalizer,
        }
        arguments.keys.each do |key|
          value = arguments[key]
          arguments.delete(key) if value.nil? or value.empty?
        end
        arguments
      end

      private
      def parse_flags(flags)
        if flags.is_a?(Array)
          flags
        else
          flags.strip.split(/\s*\|\s*/)
        end
      end

      def parse_items(items)
        if items.is_a?(Array)
          items
        else
          items.strip.split(/\s*,\s*/)
        end
      end

      class IndexDefinition
        def initialize(table, raw)
          @table = table
          @raw = raw
        end

        def name
          @raw[:name]
        end

        def source_table
          @raw[:source_table]
        end

        def source_columns
          @raw[:source_columns]
        end

        def flags
          _flags = ["COLUMN_INDEX"]
          _flags << "WITH_POSITION" if @table.use_n_gram_tokenizer?
          _flags << "WITH_SECTION" if source_columns.size >= 2
          _flags
        end

        def to_create_arguments
          {
            "table"  => @table.name,
            "name"   => name,
            "flags"  => flags.join,
            "type"   => source_table,
            "source" => source_columns,
          }
        end
      end
    end

    class TablesCreator
      def initialize(client, definitions)
        @client = client
        @definitions = definitions
      end

      def create
        return if @definitions.empty?

        table_list = @client.execute("table_list")
        @definitions.each do |definition|
          existing_table = table_list.find do |table|
            table.name == definition.name
          end
          if existing_table
            if definition.have_difference?(existing_table)
              # TODO: Is it OK?
              @client.execute("table_remove", "name" => definition.name)
            end
            @client.execute("table_create", definition.to_create_arguments)
          end

          definition.indexes.each do |index|
            @client.execute("column_create", index.to_create_arguments)
          end
        end
      end
    end

    class Schema
      def initialize(client, table_name)
        @client = client
        @table_name = table_name
        @table = nil
        @columns = nil
      end

      def update(records)
        ensure_table
        ensure_columns

        nonexistent_columns = {}
        records.each do |record|
          record.each do |key, value|
            column = @columns[key]
            if column.nil?
              nonexistent_columns[key] ||= []
              nonexistent_columns[key] << value
            end
          end
        end

        nonexistent_columns.each do |name, values|
          @columns[name] = create_column(name, values)
        end
      end

      private
      def ensure_table
        return if @table

        table_list = @client.execute("table_list")
        target_table = table_list.find do |table|
          table.name == @table_name
        end
        if target_table
          @table = Table.new(@table_name, target_table.domain)
        else
          # TODO: Check response
          @client.execute("table_create",
                          "name"  => @table_name,
                          "flags" => "TABLE_NO_KEY")
          @table = Table.new(@table_name, nil)
        end
      end

      def ensure_columns
        return if @columns

        column_list = @client.execute("column_list", "table" => @table_name)
        @columns = {}
        column_list.each do |column|
          vector_p = column.flags.split("|").include?("COLUMN_VECTOR")
          @columns[column.name] = Column.new(column.name,
                                             column.range,
                                             vector_p)
        end
      end

      def create_column(name, sample_values)
        guesser = TypeGuesser.new(sample_values)
        value_type = guesser.guess
        vector_p = guesser.vector?
        if vector_p
          flags = "COLUMN_VECTOR"
        else
          flags = "COLUMN_SCALAR"
        end
        # TODO: Check response
        @client.execute("column_create",
                        "table" => @table_name,
                        "name" => name,
                        "flags" => flags,
                        "type" => value_type)
        Column.new(name, value_type, vector_p)
      end

      class TypeGuesser
        def initialize(sample_values)
          @sample_values = sample_values
        end

        def guess
          return "Time"          if time_values?
          return "Int32"         if int32_values?
          return "Int64"         if int64_values?
          return "Float"         if float_values?
          return "WGS84GeoPoint" if geo_point_values?

          "Text"
        end

        def vector?
          @sample_values.any? do |sample_value|
            sample_value.is_a?(Array)
          end
        end

        private
        def integer_value?(value)
          case value
          when String
            begin
              Integer(value)
              true
            rescue ArgumentError
              false
            end
          when Integer
            true
          else
            false
          end
        end

        def time_values?
          now = Time.now.to_i
          year_in_seconds = 365 * 24 * 60 * 60
          window = 10 * year_in_seconds
          new = now + window
          old = now - window
          recent_range = old..new
          @sample_values.all? do |sample_value|
            integer_value?(sample_value) and
              recent_range.cover?(Integer(sample_value))
          end
        end

        def int32_values?
          int32_min = -(2 ** 31)
          int32_max = 2 ** 31 - 1
          range = int32_min..int32_max
          @sample_values.all? do |sample_value|
            integer_value?(sample_value) and
              range.cover?(Integer(sample_value))
          end
        end

        def int64_values?
          @sample_values.all? do |sample_value|
            integer_value?(sample_value)
          end
        end

        def float_value?(value)
          case value
          when String
            begin
              Float(value)
              true
            rescue ArgumentError
              false
            end
          when Float
            true
          else
            false
          end
        end

        def float_values?
          @sample_values.all? do |sample_value|
            float_value?(sample_value)
          end
        end

        def geo_point_values?
          @sample_values.all? do |sample_value|
            sample_value.is_a?(String) and
              /\A-?\d+(?:\.\d+)[,x]-?\d+(?:\.\d+)\z/ =~ sample_value
          end
        end
      end

      class Table
        def initialize(name, key_type)
          @name = name
          @key_type = key_type
        end
      end

      class Column
        def initialize(name, value_type, vector_p)
          @name = name
          @value_type = value_type
          @vector_p = vector_p
        end
      end
    end

    class Emitter
      def initialize(client, table)
        @client = client
        @table = table
        @schema = nil
      end

      def start
        @schema = Schema.new(@client, @table)
      end

      def shutdown
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
            @client.execute(name, record)
          else
            records << record
          end
        end
        store_records(records) unless records.empty?
      end

      private
      def store_records(records)
        return if @table.nil?

        @schema.update(records)

        arguments = {
          "table" => @table,
          "values" => Yajl::Encoder.encode(records),
        }
        @client.execute("load", arguments)
      end
    end

    class BaseClient
      private
      def build_command(name, arguments={})
        command_class = Groonga::Command.find(name)
        command_class.new(name, arguments)
      end
    end

    class NetworkClient < BaseClient
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

      def execute(name, arguments={})
        command = build_command(name, arguments)
        @client ||= Groonga::Client.new(:protocol => @protocol,
                                        :host     => @host,
                                        :port     => @port,
                                        :backend  => :synchronous)
        response = @client.execute(command)
        unless response.success?
          $log.error("[output][groonga][error]",
                     :status_code => response.status_code,
                     :message => response.message)
        end
        response
      end
    end

    class CommandClient < BaseClient
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

      def execute(name, arguments={})
        command = build_command(name, arguments)
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
          $log.debug("[output][groonga][output]",
                     :context => context,
                     :message => output_message)
        end
        unless error_message.empty?
          $log.error("[output][groonga][error]",
                     :context => context,
                     :message => error_message)
        end
      end
    end
  end
end
