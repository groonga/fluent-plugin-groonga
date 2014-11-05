# Copyright (C) 2014  Kouhei Sutou <kou@clear-code.com>
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

require "fluent/plugin/out_groonga"

class OutputTypeTableDefinitionTest < Test::Unit::TestCase
  def definition(raw={})
    Fluent::GroongaOutput::TableDefinition.new(raw)
  end

  sub_test_case "readers" do
    sub_test_case "\#name" do
      test "specified" do
        assert_equal("Tags", definition(:name => "Tags").name)
      end
    end

    sub_test_case "\#flags" do
      test "default" do
        assert_equal(["TABLE_NO_KEY"],
                     definition.flags)
      end

      test "one" do
        assert_equal(["TABLE_PAT_KEY"],
                     definition(:flags => "TABLE_PAT_KEY").flags)
      end
    end

    sub_test_case "\#key_type" do
      test "default" do
        assert_nil(definition.key_type)
      end

      test "specified" do
        assert_equal("ShortText",
                     definition(:key_type => "ShortText").key_type)
      end
    end

    sub_test_case "\#default_tokenizer" do
      def read_default_tokenizer(input)
        definition(:default_tokenizer => input).default_tokenizer
      end

      test "default" do
        assert_nil(definition.default_tokenizer)
      end

      test "specified" do
        assert_equal("TokenBigram",
                     read_default_tokenizer("TokenBigram"))
      end
    end

    sub_test_case "\#token_filters" do
      def read_token_filters(input)
        definition(:token_filters => input).token_filters
      end

      test "default" do
        assert_equal([], definition.token_filters)
      end

      test "one" do
        assert_equal(["TokenFilterStem"],
                      read_token_filters("TokenFilterStem"))
      end

      test "multiple" do
        assert_equal(["TokenFilterStem", "TokenFilterStopWord"],
                      read_token_filters("TokenFilterStem,TokenFilterStopWord"))
      end
    end

    sub_test_case "\#normalizer" do
      def read_normalizer(input)
        definition(:normalizer => input).normalizer
      end

      test "default" do
        assert_nil(definition.normalizer)
      end

      test "specified" do
        assert_equal("NormalizerAuto",
                     read_normalizer("NormalizerAuto"))
      end
    end
  end

  sub_test_case "\#have_difference?" do
    def setup
      @existing_table = Groonga::Client::Response::TableList::Table.new
      @existing_table.id = 260
      @existing_table.name = "Paths"
      @existing_table.path = "/var/lib/groonga/db/db.0000104"
      @existing_table.flags = "TABLE_PAT_KEY|PERSISTENT"
      @existing_table.domain = "ShortText"
      @existing_table.range = nil
      @existing_table.default_tokenizer = nil
      @existing_table.normalizer = nil
    end

    def have_difference?(raw={})
      default_raw = {
        :name              => @existing_table.name,
        :flags             => @existing_table.flags.gsub(/\|PERSISTENT/, ""),
        :key_type          => @existing_table.domain,
        :default_tokenizer => @existing_table.default_tokenizer,
        :normalizer        => @existing_table.normalizer,
      }
      raw = default_raw.merge(raw)
      definition(raw).have_difference?(@existing_table)
    end

    test "no difference" do
      assert do
        not have_difference?
      end
    end

    sub_test_case "difference" do
      test "name" do
        assert do
          have_difference?(:name => "Difference")
        end
      end

      test "flags" do
        assert do
          have_difference?(:flags => "TABLE_NO_KEY")
        end
      end

      test "key_type" do
        assert do
          have_difference?(:key_type => "UInt32")
        end
      end

      test "default_tokenizer" do
        assert do
          have_difference?(:default_tokenizer => "TokenBigram")
        end
      end

      test "normalizer" do
        assert do
          have_difference?(:normalizer => "NormalizerAuto")
        end
      end
    end
  end
end
