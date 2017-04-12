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

class OutputTypeTableIndexDefinitionTest < Test::Unit::TestCase
  def table_definition
    raw = {
      :name              => "Terms",
      :default_tokenizer => "TokenBigram",
    }
    Fluent::Plugin::GroongaOutput::TableDefinition.new(raw)
  end

  def definition(raw={})
    default_raw = {
      :source_columns => "title",
    }
    raw = default_raw.merge(raw)
    Fluent::Plugin::GroongaOutput::TableDefinition::IndexDefinition.new(table_definition,
                                                                raw)
  end

  sub_test_case "readers" do
    sub_test_case "\#name" do
      test "specified" do
        assert_equal("logs_index", definition(:name => "logs_index").name)
      end
    end

    sub_test_case "\#flags" do
      test "default" do
        assert_equal(["COLUMN_INDEX", "WITH_POSITION"],
                     definition.flags)
      end

      test "multiple source columns" do
        assert_equal(["COLUMN_INDEX", "WITH_POSITION", "WITH_SECTION"],
                     definition(:source_columns => "title,content").flags)
      end
    end

    sub_test_case "\#source_table" do
      test "specified" do
        assert_equal("Logs",
                     definition(:source_table => "Logs").source_table)
      end
    end

    sub_test_case "\#source_columns" do
      test "one" do
        assert_equal(["title"],
                     definition(:source_columns => "title").source_columns)
      end

      test "multiple" do
        raw = {
          :source_columns => "title,content",
        }
        assert_equal(["title", "content"],
                     definition(raw).source_columns)
      end
    end
  end

  sub_test_case "\#to_create_arguments" do
    test "full" do
      raw = {
        :name           => "logs_index",
        :source_table   => "Logs",
        :source_columns => "title, content",
      }
      assert_equal({
                     "table"  => "Terms",
                     "name"   => "logs_index",
                     "flags"  => "COLUMN_INDEX|WITH_POSITION|WITH_SECTION",
                     "type"   => "Logs",
                     "source" => "title,content",
                   },
                   definition(raw).to_create_arguments)
    end
  end
end
