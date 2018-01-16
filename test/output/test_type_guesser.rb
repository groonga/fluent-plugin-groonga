# Copyright (C) 2014  Kouhei Sutou <kou@clear-code.com>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

require "fluent/plugin/out_groonga"

class OutputTypeGuesserTest < Test::Unit::TestCase
  sub_test_case "#guess" do
    def guess(sample_values)
      guesser = Fluent::Plugin::GroongaOutput::Schema::TypeGuesser.new(sample_values)
      guesser.guess
    end

    sub_test_case "Bool" do
      test "true" do
        assert_equal("Bool", guess([true]))
      end

      test "false" do
        assert_equal("Bool", guess([false]))
      end

      test "string" do
        assert_equal("Bool", guess(["true", "false"]))
      end
    end

    sub_test_case "Time" do
      test "now" do
        now = Time.now.to_i
        assert_equal("Time", guess([now]))
      end

      test "past value" do
        now = Time.now.to_i
        year_in_seconds = 365 * 24 * 60 * 60
        past = now - (9 * year_in_seconds)
        assert_equal("Time", guess([past]))
      end

      test "future value" do
        now = Time.now.to_i
        year_in_seconds = 365 * 24 * 60 * 60
        future = now + (9 * year_in_seconds)
        assert_equal("Time", guess([future]))
      end

      test "all type values" do
        now = Time.now.to_i
        year_in_seconds = 365 * 24 * 60 * 60
        past = now - (9 * year_in_seconds)
        future = now + (9 * year_in_seconds)
        assert_equal("Time", guess([now, past, future]))
      end

      test "string" do
        now = Time.now.to_i
        assert_equal("Time", guess([now.to_s]))
      end
    end

    sub_test_case "Int32" do
      test "min" do
        int32_min = -(2 ** 31)
        assert_equal("Int32", guess([int32_min]))
      end

      test "max" do
        int32_max = 2 ** 31 - 1
        assert_equal("Int32", guess([int32_max]))
      end

      test "zero" do
        assert_equal("Int32", guess([0]))
      end

      test "string" do
        assert_equal("Int32", guess(["0"]))
      end
    end

    sub_test_case "Int64" do
      test "int32_min - 1" do
        int32_min = -(2 ** 31)
        assert_equal("Int64", guess([int32_min - 1]))
      end

      test "int32_max + 1" do
        int32_max = 2 ** 31 - 1
        assert_equal("Int64", guess([int32_max + 1]))
      end

      test "string" do
        assert_equal("Int64", guess([(2 ** 32).to_s]))
      end
    end

    sub_test_case "Float" do
      test "positive" do
        assert_equal("Float", guess([1.0]))
      end

      test "negative" do
        assert_equal("Float", guess([-1.0]))
      end

      test "zero" do
        assert_equal("Float", guess([0.0]))
      end

      test "string" do
        assert_equal("Float", guess(["1.1"]))
      end
    end

    sub_test_case "WGS84GeoPoint" do
      test "\#{LATITUDE},\#{LONGITUDE}" do
        statue_of_liberty = "40.689167,-74.044444"
        assert_equal("WGS84GeoPoint", guess([statue_of_liberty]))
      end

      test "\#{LATITUDE}x\#{LONGITUDE}" do
        statue_of_liberty = "40.689167x-74.044444"
        assert_equal("WGS84GeoPoint", guess([statue_of_liberty]))
      end
    end

    sub_test_case "ShortText" do
      test "max" do
        message = "X" * (2 ** 12)
        assert_equal("ShortText", guess([message]))
      end

      test "nil" do
        assert_equal("ShortText", guess([nil]))
      end
    end

    sub_test_case "Text" do
      test "min" do
        message = "X" * (2 ** 12 + 1)
        assert_equal("Text", guess([message]))
      end

      test "max" do
        message = "X" * (2 ** 16)
        assert_equal("Text", guess([message]))
      end
    end

    sub_test_case "LongText" do
      test "min" do
        message = "X" * (2 ** 16 + 1)
        assert_equal("LongText", guess([message]))
      end
    end
  end
end
