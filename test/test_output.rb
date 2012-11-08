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
require "fluent/plugin/out_groonga"

require "http_parser"

class GroongaOutputTest < Test::Unit::TestCase
  setup
  def setup_fluent
    Fluent::Test.setup
  end

  private
  def create_driver(tag)
    driver = Fluent::Test::BufferedOutputTestDriver.new(Fluent::GroongaOutput,
                                                        tag)
    driver.configure(configuration)
    driver
  end

  def configuration
    <<-EOC
EOC
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
      @database_path = File.join(@temporary_directory, "database")

      File.open(@groonga_stub_path, "w") do |groonga_stub|
        groonga_stub.puts(<<-EOR)
#!#{Gem.ruby}

File.open(#{@command_line_path.inspect}, "a") do |file|
  file.puts(ARGV)
end

input_fd = ARGV[ARGV.index("--input-fd") + 1]
input = IO.new(input_fd.to_i)

File.open(#{@input_path.inspect}, "a") do |file|
  input.each_line do |line|
    file.print(line)
  end
end

output_fd = ARGV[ARGV.index("--output-fd") + 1]
output = IO.new(output_fd.to_i)
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

    class CommandTest < self
      def test_basic_command
        driver = create_driver("groonga.command.table_create")
        time = Time.parse("2012-10-26T08:45:42Z")
        driver.emit({"name" => "Users"}, time)
        driver.run
        assert_equal([
                       [
                         "--input-fd", "5",
                         "--output-fd", "8",
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
