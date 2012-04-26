require 'test_helper'
require 'flexmock/test_unit'

class ConfigurableListListTest < ActiveSupport::TestCase
  FlexMock::TestCase

  def setup
    super
    @list_class = Class.new(ConfigurableList::List)
    @list_class.base_table :my_table

    @list_class.column :attr1, "my_table.attribute_1", :datatype => :string, :disable_filter => true, :human_name => "One"
    @list_class.column :attr2, "another_table.attribute_2", :datatype => :integer, :require_join => :another_table
    @list_class.column :attr3, "my_table.attribute_3", :datatype => :string, :filters => [{:value => "1", :condition => "= 1", :human_name => "One"}], :human_name => "Three"
    @list_class.join :other_table, "JOIN other_table ON other_table.id = my_table.other_table_id", :require_join => :yet_more_table
    @list_class.join :another_table, "JOIN another_table ON another_table.id = other_table.another_table_id", :require_join => :other_table
    @list_class.join :yet_more_table, "JOIN yet_more_table ON yet_more_table.id = my_table.yet_more_id"
    @list_class.qualifier "my_table.state = 4"
    @list_class.qualifier "yet_more_table.state = 1", :require_join => [:yet_more_table]

    @list = @list_class.new
    @list.add_column :attr4, "dyn_table.attribute_4", :datatype => :datetime, :filter_group => :one
    @list.add_column :attr5, "my_table.attribute_5", :filter_group => :one, :human_name => "Five"
    @list.add_join :dyn_table, "LEFT JOIN dyn_table ON dyn_table.id = other_table.dyn_table_id", :require_join => [:other_table,:another_table]
    @list.add_qualifier "my_table.something = 'Some '' Stuff'"
  end

  def teardown
    super
  end

  def test_list_setup
    assert_equal 5, @list.all_columns.length
    assert_equal 4, @list.all_joins.length
    assert_equal 3, @list.all_qualifiers.length
    assert_equal 2, @list.dynamic_columns.length
    assert_equal 3, @list.display_columns.length
  end

  def test_generated_sql 
    sql = <<-SQL.unindent(true)
      SELECT *, count(*) OVER() AS total_row_count FROM (
        SELECT my_table.attribute_3 AS attr3,
               my_table.attribute_5 AS attr5,
               my_table.attribute_1 AS attr1,
               dyn_table.attribute_4 AS attr4,
               another_table.attribute_2 AS attr2
        FROM my_table
        JOIN yet_more_table ON yet_more_table.id = my_table.yet_more_id
        JOIN other_table ON other_table.id = my_table.other_table_id
        JOIN another_table ON another_table.id = other_table.another_table_id
        WHERE my_table.state = 4
          AND yet_more_table.state = 1
          AND my_table.something = 'Some '' Stuff'
      ) AS intermediate_result
      WHERE (attr3 = 1) AND ((attr4 ILIKE '%four%'))
      ORDER BY attr2 DESC NULLS LAST
      LIMIT 50 OFFSET 100
    SQL
    flexmock(ActiveRecord::Base.connection).should_receive(:select_all).with(sql).once
    @list.evaluate([:attr3, :attr5, :attr1, :attr4, :attr2], 
                   :page => 3, :page_size => 50, :filters => {:attr3 => "1", :attr4 => "four"},
                   :sorts => ['attr2 desc'])
  end

  def test_prepared_result_set
    result_set = [
      {"attr1" => "12345", "attr2" => "0", "attr3" => "1qaz", "attr4" => "2010-01-01 00:00:00.000000", "attr5" => "asdf"},
      {"attr1" => "qwert", "attr2" => "1", "attr3" => "2wsx", "attr4" => "2012-01-15 12:34:56.123000", "attr5" => "asdf"},
      {"attr1" => "asdfg", "attr2" => "2", "attr3" => "3edc", "attr4" => "1970-12-01 23:45:59.000000", "attr5" => "asdf"},
      {"attr1" => "zxcvb", "attr2" => "3", "attr3" => "4rfv", "attr4" => "2004-09-10 11:12:13.141516", "attr5" => "asdf"}
    ]
    prepared = @list.send(:prepare_result_set, result_set, 2, 4, 100, [:attr5])

    assert_equal 2, prepared.current_page
    assert_equal 4, prepared.per_page
    assert_equal 100, prepared.total_entries
    assert_equal "12345", prepared[0].attr1 
    assert_equal 3, prepared[3].attr2
    assert_equal Time.local(1970,12,1,23,45,59), prepared[2].attr4
    assert_equal Time.local(2004,9,10,11,12,13,141516), prepared[3].attr4
    assert !prepared[1].members.include?("attr5")
  end

end