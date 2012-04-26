module ConfigurableList

  class Join
    attr_accessor :name, :sql_property, :join_dependencies

    def initialize(name, sql_property, options={})
      options = {
        :require_join => []
      }.merge!(options)
      @name, @sql_property, @options = name.to_sym, sql_property, options
      @join_dependencies = [*options[:require_join]]
    end

    def to_sql
      sql_property
    end

  end

  class JoinDependencies
    include TSort

    def initialize(all_joins, required)
      @all_joins, @required = all_joins, required
    end

    def tsort_each_node(&block)
      @all_joins.values_at(*@required).each(&block)
    end

    def tsort_each_child(node, &block)
      @all_joins.values_at(*node.join_dependencies).each(&block)
    end

  end

end
