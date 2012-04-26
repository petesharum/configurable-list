require 'test_helper'

class ConfigurableListQualifierTest < ActiveSupport::TestCase

  def test_basic_properties
    qualifier = ConfigurableList::Qualifier.new("property = 123", :require_join => [:one, :two])
    assert_equal "property = 123", qualifier.sql_property
    assert_equal [:one, :two], qualifier.join_dependencies
    qualifier = ConfigurableList::Qualifier.new("property = 123")
    assert_equal [], qualifier.join_dependencies
  end

  def test_to_sql
    qualifier = ConfigurableList::Qualifier.new("property = 123", :require_join => [:one, :two])
    assert_equal "property = 123", qualifier.to_sql
  end

end