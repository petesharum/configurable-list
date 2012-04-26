require 'test_helper'

class ConfigurableListJoinTest < ActiveSupport::TestCase

  def test_basic_properties
    join = ConfigurableList::Join.new("my_join", "JOIN my_table ON 1 = 1", :require_join => :other_join)
    assert_equal :my_join, join.name
    assert_equal "JOIN my_table ON 1 = 1", join.to_sql
    assert_equal [:other_join], join.join_dependencies
  end

  def test_sort_join_dependencies
    all_joins = { 
      :top => [],
      :one => [:top],
      :two => [:one],
      :a => [:top, :one],
      :b => [:top, :two],
      :bottom => [:a, :b]
    }.inject({}) { |h,(k,v)| h[k] = ConfigurableList::Join.new(k, "", :require_join => v); h }

    jd = ConfigurableList::JoinDependencies.new(all_joins , [:bottom])
    sorted = jd.tsort    
    sorted_names = sorted.inject([]) { |a, i| a << i.name }

    assert_equal :top, sorted.first.name
    assert_equal :bottom, sorted.last.name 
    assert_operator sorted_names.index(:one), :<, sorted_names.index(:two)
    assert_operator sorted_names.index(:two), :<, sorted_names.index(:b)
    assert_operator sorted_names.index(:one), :<, sorted_names.index(:a)
  end

end