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
require "fluent/plugin/in_groonga"

require "http_parser"

class GroongaInputTest < Test::Unit::TestCase
  setup :before => :append
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
    setup :before => :append
    def setup_real_server
      @real_host = "127.0.0.1"
      @real_port = 29292
      @real_server = TCPServer.new(@real_host, @real_port)
      @repeater = nil
      response_config = WEBrick::Config::HTTP.dup.update(:Logger => $log)
      @real_response = WEBrick::HTTPResponse.new(response_config)
      Thread.new do
        @repeater = @real_server.accept
        @real_server.close
        parser = HTTP::Parser.new
        parser.on_message_complete = lambda do
          @real_response.send_response(@repeater)
          @repeater.close
        end

        loop do
          break if @repeater.closed?
          data = @repeater.readpartial(4096)
          break if data.nil?
          parser << data
        end
      end
    end

    teardown
    def teardown_real_server
      @real_server.close unless @real_server.closed?

      if @repeater and not @repeater.closed?
        @repeater.close
      end
    end

    def setup
      @host = "127.0.0.1"
      @port = 2929

      @driver = create_driver
      @last_response = nil
    end

    def configuration
      <<-EOC
      protocol http
      bind #{@host}
      port #{@port}
      real_host #{@real_host}
      real_port #{@real_port}
EOC
    end

    def test_target_command
      @real_response["Content-Type"] = "application/json"
      @real_response.body = JSON.generate([[0, 0.0, 0.0], true])
      @driver.expect_emit("groonga.command.table_create",
                          @now,
                          {
                            "name" => "Users",
                            "flags" => "TABLE_NO_KEY",
                          })
      @driver.run do
        get("/d/table_create", "name" => "Users", "flags" => "TABLE_NO_KEY")
        assert_equal("200", @last_response.code)
      end
    end

    def test_not_target_command
      @driver.run do
        get("/d/status")
        assert_equal("200", @last_response.code)
      end
      assert_empty(@driver.emits)
    end

    def test_load
      @real_response["Content-Type"] = "application/json"
      @real_response.body = JSON.generate([[0, 0.0, 0.0], 2])
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
                            "values" => json,
                          })

      @driver.run do
        post("/d/load", json, "table" => "Users")
        assert_equal("200", @last_response.code)
      end
    end

    def test_not_command
      @driver.run do
        @real_response.status = 404
        get("/index.html")
        assert_equal("404", @last_response.code)
      end
    end

    private
    def get(path, parameters={})
      http = Net::HTTP.new(@host, @port)
      response = http.get(build_path(path, parameters))
      @last_response = response
      response
    end

    def post(path, body, parameters={})
      http = Net::HTTP.new(@host, @port)
      response = http.post(build_path(path, parameters),
                           body,
                           {"Content-Type" => "application/json"})
      @last_response = response
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
