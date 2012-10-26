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

require "fluent/test"
require "fluent/plugin/in_groonga"

class GroongaInputTest < Test::Unit::TestCase
  setup
  def setup_fluent
    Fluent::Test.setup
    @now = Time.parse("2012-10-26T08:45:42Z").to_i
    Fluent::Engine.now = @now
  end

  private
  def create_driver
    driver = Fluent::Test::InputTestDriver.new(Fluent::GroongaInput)
    driver.configure(configuration)
    driver
  end

  def configuration
    <<-EOC
EOC
  end

  class HTTPTest < self
    def setup
      @host = "127.0.0.1"
      @port = 2929

      @driver = create_driver
    end

    def configuration
      <<-EOC
      protocol http
      bind #{@host}
      port #{@port}
EOC
    end

    def test_basic_command
      @driver.expect_emit("groonga.command.table_create",
                          @now,
                          {"name" => "Users"})

      @driver.run do
        get("/d/table_create", "name" => "Users")
      end
    end

    def test_load
      json = <<-EOJ
[
{"name": "Alice"},
{"name": "Bob"}
]
EOJ
      @driver.expect_emit("groonga.command.load",
                          @now,
                          {
                            "table" => "Users",
                            "data" => json,
                          })

      @driver.run do
        post("/d/load", json, "table" => "Users")
      end
    end

    private
    def get(path, parameters={})
      http = Net::HTTP.new(@host, @port)
      response = http.get(build_path(path, parameters))
      assert_equal("200", response.code)
      response
    end

    def post(path, body, parameters={})
      http = Net::HTTP.new(@host, @port)
      response = http.post(build_path(path, parameters),
                           body,
                           {"Content-Type" => "application/json"})
      assert_equal("200", response.code)
      response
    end

    def build_path(path, parameters)
      unless parameters.empty?
        url_encoded_parameters = parameters.collect do |key, value|
          "#{CGI.escape(key)}=#{CGI.escape(value)}"
        end
        path += "?" + url_encoded_parameters.join("&")
      end
      path
    end
  end
end
