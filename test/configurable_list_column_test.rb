require 'test_helper'

class ConfigurableListColumnTest < ActiveSupport::TestCase

  def test_basic_properties
    column = ConfigurableList::Column.new('my_col', "my_col", :require_join => :required)
    assert_equal :my_col, column.name
    assert_equal [:required], column.join_dependencies
  end

  def test_simple_property_sql
    column = ConfigurableList::Column.new(:my_col, "my_col")
    assert_equal "my_col AS my_col", column.to_sql
  end

  def test_complex_property
    column = ConfigurableList::Column.new(:my_col, "(SELECT val FROM my_table WHERE my_table.attr = 9)")
    assert_equal "(SELECT val FROM my_table WHERE my_table.attr = 9) AS my_col", column.to_sql
  end

  def test_sort_ascending
    column1 = ConfigurableList::Column.new(:my_col, "my_col")
    assert_equal "my_col ASC NULLS LAST", column1.sort_sql

    column2 = ConfigurableList::Column.new(:my_col, "my_col", :sort_nulls_last => false)
    assert_equal "my_col ASC", column2.sort_sql
  end

  def test_sort_descending
    column1 = ConfigurableList::Column.new(:my_col, "my_col")
    assert_equal "my_col DESC NULLS LAST", column1.sort_sql(true)

    column2 = ConfigurableList::Column.new(:my_col, "my_col", :sort_nulls_last => false)
    assert_equal "my_col DESC", column2.sort_sql(true)
  end

  def test_filter_sql_disabled 
    column = ConfigurableList::Column.new(:my_col, "my_col", :disable_filter => true)
    assert_nil column.filter_sql
  end

  def test_filter_sql_text_match
    column = ConfigurableList::Column.new(:my_col, "my_col")
    assert_equal "my_col ILIKE '%filter%'", column.filter_sql('filter')
    assert_equal "my_col ILIKE '%fil''ter%'", column.filter_sql("fil'ter")
  end

  def test_filter_sql_options
    my_filters = [
      {:value => "1", :condition => "= 1", :human_name => "One"},
      {:value => "2", :condition => "= 2", :human_name => "Two"},
      {:value => "3", :condition => "> 3", :human_name => "Three"}
    ]
    column = ConfigurableList::Column.new(:my_col, "my_col", :filters => my_filters)
    assert_equal "my_col = 2", column.filter_sql("2")
    assert_equal "1=1", column.filter_sql("4")
  end

  def test_filter_sql_proc_options
    t = Time.now
    my_filters = [
      {:value => "1", :condition => lambda { "< #{t.to_s(:db)}"}}
    ]
    column = ConfigurableList::Column.new(:my_col, "my_col", :filters => my_filters)
    assert_equal "my_col < #{t.to_s(:db)}", column.filter_sql("1")
  end

  def test_bad_filter_options_raises_exception
    my_filters = [{:value => 1, :condition => "=1"}]
    assert_raises RuntimeError do 
      column = ConfigurableList::Column.new(:my_col, "my_col", :filters => my_filters)
    end
  end

  def test_type_cast_string
    column = ConfigurableList::Column.new(:my_col, "my_col", :datatype => :string)
    assert_equal nil, column.type_cast(nil)
    assert_equal "foo", column.type_cast("foo")
  end

  def test_type_cast_integer
    column = ConfigurableList::Column.new(:my_col, "my_col", :datatype => :integer)
    assert_equal nil, column.type_cast(nil)
    assert_equal 1, column.type_cast("1")
  end

  def test_type_cast_float
    column = ConfigurableList::Column.new(:my_col, "my_col", :datatype => :float)
    assert_equal nil, column.type_cast(nil)
    assert_equal 1.23, column.type_cast("1.23")
  end

  def test_type_cast_datetime
    column = ConfigurableList::Column.new(:my_col, "my_col", :datatype => :datetime)
    assert_equal nil, column.type_cast(nil)
    assert_equal Time.local(1970,1,1).to_i, column.type_cast("1970-01-01 00:00:00.000000").to_i
    assert_equal Time.local(2012,2,29,12,34,56,7890).to_i, column.type_cast("2012-02-29 12:34:56.007890").to_i
  end

  def test_type_cast_boolean
    column = ConfigurableList::Column.new(:my_col, "my_col", :datatype => :boolean)
    assert_equal nil, column.type_cast(nil)
    assert_equal true, column.type_cast("TRUE")
    assert_equal false, column.type_cast("FALSE")
  end

  def test_humanize
    column = ConfigurableList::Column.new(:my_col, "my_col")
    assert_equal "NoChanges_Made", column.humanize("NoChanges_Made")
  end

  def test_humanize_with_format
    column = ConfigurableList::Column.new(:my_col, "my_col", :format => "%d%% more awesome!")
    assert_equal "99% more awesome!", column.humanize(99)
  end

  def test_humanize_with_proc
    formatter = lambda { |value| value.present? ? value.strftime("%A %B %d") : "Never" }
    column = ConfigurableList::Column.new(:my_col, "my_col", :format => formatter)
    time = Time.local(2012, 2, 29, 12, 00, 00)
    assert_equal "Wednesday February 29", column.humanize(time)
    assert_equal "Never", column.humanize(nil)
  end

end