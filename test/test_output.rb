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

require "time"
require "cgi/util"
require "net/http"
require "webrick/config"
require "webrick/httpresponse"

require "fluent/test"
require 'fluent/test/helpers'
require "fluent/plugin/out_groonga"
require "fluent/test/driver/output"

require "http_parser"

class GroongaOutputTest < Test::Unit::TestCase
  include Fluent::Test::Helpers
  setup :before => :append
  def setup_fluent
    Fluent::Test.setup
  end

  private
  def create_driver
    driver = Fluent::Test::Driver::Output.new(Fluent::Plugin::GroongaOutput)
    driver.configure(configuration)
    driver
  end

  def configuration
    <<-EOC
EOC
  end

  class HTTPTest < self
    setup :before => :append
    def setup_real_server
      @request_parser = HTTP::Parser.new
      @request_body = ""
      @response_body = nil

      @real_host = "127.0.0.1"
      @real_port = 29292
      @real_server_thread = Thread.new do
        @real_server = TCPServer.new(@real_host, @real_port)
        loop do
          response_config = WEBrick::Config::HTTP.dup.update(:Logger => $log)
          real_response = WEBrick::HTTPResponse.new(response_config)
          request_headers = nil
          request_body = ""
          client = @real_server.accept
          @request_parser.on_body = lambda do |chunk|
            @request_body << chunk
          end
          @request_parser.on_message_complete = lambda do
            real_response.body = @response_body
            real_response.send_response(client)
            client.close
          end

          loop do
            break if client.closed?
            data = client.readpartial(4096)
            break if data.nil?
            @request_parser << data
          end
        end
      end
    end

    teardown
    def teardown_real_server
      @real_server_thread.kill
      @real_server.close
    end

    def configuration
      <<-EOC
      protocol http
      host #{@real_host}
      port #{@real_port}
EOC
    end

    class CommandTest < self
      def test_basic_command
        @response_body = JSON.generate([[0, 0.0, 0.0], true])
        driver = create_driver
        time = event_time("2012-10-26T08:45:42Z").to_i
        driver.run(default_tag: "groonga.command.table_create") do
          driver.feed(time, {"name" => "Users"})
        end
        assert_equal("/d/table_create?name=Users",
                     @request_parser.request_url)
      end
    end

    class StoreTest < self
      def configuration
        <<-CONFIGURATION
          #{super}
          store_table Logs
        CONFIGURATION
      end

      def test_one_message
        @response_body = JSON.generate([[0, 0.0, 0.0], [1]])
        driver = create_driver
        time = event_time("2012-10-26T08:45:42Z").to_i
        driver.run(default_tag: "log") do
          driver.feed(time, {"message" => "1st message"})
        end
        assert_equal("/d/load?table=Logs",
                     @request_parser.request_url)
        assert_equal([{"message" => "1st message"}],
                     JSON.parse(@request_body))
      end

      def test_multiple_messages
        @response_body = JSON.generate([[0, 0.0, 0.0], [2]])
        driver = create_driver
        time = event_time("2012-10-26T08:45:42Z").to_i
        driver.run(default_tag: "log") do
          driver.feed(time, {"message" => "1st message"})
          driver.feed(time + 1, {"message" => "2nd message"})
        end
        assert_equal("/d/load?table=Logs",
                     @request_parser.request_url)
        assert_equal([
                       {"message" => "1st message"},
                       {"message" => "2nd message"},
                     ],
                     JSON.parse(@request_body))
      end
    end
  end

  class CommandLineTest < self
    setup :before => :append
    def setup_command
      @temporary_directory = File.expand_path("tmp", File.dirname(__FILE__))
      FileUtils.rm_rf(@temporary_directory)
      FileUtils.mkdir_p(@temporary_directory)

      @groonga_stub_path = File.join(@temporary_directory, "groonga")
      @command_line_path = File.join(@temporary_directory, "command-line")
      @input_path = File.join(@temporary_directory, "input")
      @input_fd_path = File.join(@temporary_directory, "input-fd")
      @output_fd_path = File.join(@temporary_directory, "output-fd")
      @database_path = File.join(@temporary_directory, "database")

      File.open(@groonga_stub_path, "w") do |groonga_stub|
        groonga_stub.puts(<<-EOR)
#!#{Gem.ruby}

File.open(#{@command_line_path.inspect}, "a") do |file|
  file.puts(ARGV)
end

input_fd = ARGV[ARGV.index("--input-fd") + 1]
input = IO.new(input_fd.to_i)

File.open(#{@input_fd_path.inspect}, "a") do |file|
  file.print(input_fd)
end

File.open(#{@input_path.inspect}, "a") do |file|
  input.each_line do |line|
    file.print(line)
  end
end

output_fd = ARGV[ARGV.index("--output-fd") + 1]
output = IO.new(output_fd.to_i)

File.open(#{@output_fd_path.inspect}, "a") do |file|
  file.print(output_fd)
end

output.puts("done")
output.flush
EOR
      end
      FileUtils.chmod(0755, @groonga_stub_path)

      FileUtils.touch(@command_line_path)
      FileUtils.touch(@input_path)
    end

    teardown
    def teardown_command
      FileUtils.rm_rf(@temporary_directory)
    end

    def configuration
      <<-EOC
      protocol command
      groonga #{@groonga_stub_path}
      database #{@database_path}
EOC
    end

    private
    def actual_command_line
      File.read(@command_line_path).split(/\n/)
    end

    def actual_input
      File.read(@input_path)
    end

    def actual_input_fd
      File.read(@input_fd_path)
    end

    def actual_output_fd
      File.read(@output_fd_path)
    end

    class CommandTest < self
      def test_basic_command
        driver = create_driver
        time = event_time("2012-10-26T08:45:42Z").to_i
        driver.run(default_tag: "groonga.command.table_create") do
          driver.feed(time, {"name" => "Users"})
        end
        assert_equal([
                       [
                         "--input-fd", actual_input_fd,
                         "--output-fd", actual_output_fd,
                         "-n", @database_path,
                       ],
                       "/d/table_create?name=Users\n",
                     ],
                     [
                       actual_command_line,
                       actual_input,
                     ])
      end
    end
  end
end
