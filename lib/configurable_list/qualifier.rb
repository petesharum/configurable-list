module ConfigurableList

  class Qualifier
    attr_accessor :sql_property, :join_dependencies

    def initialize(sql_property, options={})
      options = {
        :require_join => []
      }.merge!(options)
      @sql_property, @options = sql_property, options
      @join_dependencies = [*options[:require_join]]
    end

    def to_sql
      sql_property
    end

  end

end