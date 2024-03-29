module ConfigurableList

  # 
  # ConfigurableList::List is a basic query builder and evaluation tool. 
  # 
  # Subclasses of List can be created to define the behavior of a "Configurable
  # List View." Columns, column ordering, sorts, filters and paging are 
  # supported.
  # 
  # Columns, joins and qualifiers can be defined at the class or instance level. 
  # Once instantiated, an object of a List subclass type can be used to 
  # retrieve list data or to supply configuration options to a list configuration UI. 
  # 
  # Join dependencies can be specified with the :require_join property on any column, 
  # qualifier or join. Join dependency ordering is handled automatically. 
  # 
  class List

    def self.base_table(table)
      @table_name = table.to_s
    end

    def self.table_name
      @table_name
    end

    # 
    # Add a column to the list specification. Used by subclasses to declare
    # columns available to all instances of the list. Columns can optionally
    # declare filters, human (display) names, formats and sorting behavior. 
    # 
    # name: Symbol name to identify this column in code. 
    # 
    # sql_property: SQL column to populate this list column. To avoid ambiguity
    #               it's better to indicate the table name explicitly. 
    #               ex: "my_table.attribute1" is better than "attribute1"
    # 
    # options:
    #   * :datatype - Type of retrieved column. ConfigurableList::List will 
    #                 attempt to type cast results appropriately. 
    #                 Supported types are :string (default), :integer, :float, 
    #                 :datetime and :boolean.
    # 
    #   * :require_join - Include joins required for this column (see #join). 
    #                     Accepts a symbol or array of symbols. (default [])
    # 
    #   * :filter - Filter SQL sprintf string or a proc that accepts the value
    #               and returns a sprintf string (default "ILIKE '%%%s%%'").
    # 
    #   * :filters - By default columns support filters with an ILIKE clause. 
    #                Specify filters with an array to declare a set of
    #                supported filters (to use in a <SELECT> element for 
    #                example). Each element should be a hash:
    # 
    #                  { :value => '1', :condition => "<= 0", :human_name => "Overdue", :dislpay_suffix => "[12]" }
    # 
    #                :value must be a string. 
    #                :condition can be either a string qualifier or a proc that
    #                 returns a string qualifier.
    #                :human_name is optional. 
    #                :display_suffix is optional. 
    #                An exception will be raised for filters do not meet data type requirements.
    # 
    #   * :disable_filter - Disallow filters on this column (default false).
    # 
    #   * :filter_group - By default all filters are exclusive (they are 
    #                     joined together in the query by "AND"). 
    #                     Filters on columns with the same :filter_group value 
    #                     are inclusive. They are joined by "OR" before joining 
    #                     to other specified filters with "AND".
    # 
    #   * :sort_nulls_last - Always sort nulls to the end (default true)
    # 
    #   * :human_name - Give a column a human name for it to be identified in 
    #                   #display_columns. Can also be used later in a 
    #                   configuration UI. 
    # 
    #   * :format - Specify either a sprintf formatted string or a proc that 
    #               accepts a value and returns the formatted version.
    # 
    def self.column(name, sql_property, options={})
      columns[name.to_sym] = ConfigurableList::Column.new(name, sql_property, options)
    end

    # 
    # Add a join to the list specification. Used by subclasses to declare
    # join available to all instances of the list. 
    # 
    # name: Symbol name to identify this join in code. 
    # 
    # sql_property: full text of SQL join.
    #               ex: "LEFT JOIN table2 ON table2.id = table1.table1_id"
    # options: 
    #   * :require_join - Include joins required for this column in the query. 
    #                     Accepts a symbol or array of symbols. (default [])
    # 
    def self.join(name, sql_property, options={})
      joins[name.to_sym] = ConfigurableList::Join.new(name, sql_property, options)
    end

    # 
    # Add a WHERE clause qualfier to the list specification. Used by subclasses
    # to qualifiers for all instances of the list. All qualifiers will be 
    # joined together with "AND" in the query generated by this list. 
    # 
    # name: Symbol name to identify this join in code. 
    # 
    # sql_property: full text of SQL qualifier.
    #               ex: "attribute => 2000"
    # options: 
    #   * :require_join - Include joins required for this qualfier (see #join). 
    #                     Accepts a symbol or array of symbols. (default [])
    # 
    def self.qualifier(sql_property, options={})
      qualifiers << ConfigurableList::Qualifier.new(sql_property, options)
    end

    def initialize
      @dynamic_columns = {}
      @dynamic_joins = {}
      @dynamic_qualifiers = []
    end

    # Add a column definition specific to this instance (see ::column).
    def add_column(name, sql_property, options={})
      @dynamic_columns[name.to_sym] = ConfigurableList::Column.new(name, sql_property, options)
      # invalidate cached all_columns
      @all_columns = nil
    end

    # Add a join definition specific to this instance (see ::join).
    def add_join(name, sql_property, options={})
      @dynamic_joins[name.to_sym] = ConfigurableList::Join.new(name, sql_property, options)
      # invalidate cached all_joins
      @all_joins = nil
    end

    # Add a qualifier definition specific to this instance (see ::qualifier).
    def add_qualifier(sql_property, options={})
      @dynamic_qualifiers << ConfigurableList::Qualifier.new(sql_property, options)
      # invalidate cached all_qualifiers
      @all_qualifiers = nil
    end

    def all_columns
      @all_columns ||= self.class.columns.merge @dynamic_columns
    end

    def display_columns
      all_columns.reject {|key,value| value.human_name.nil?}
    end

    def dynamic_columns
      @dynamic_columns
    end

    def all_joins
      @all_joins ||= self.class.joins.merge @dynamic_joins
    end

    def all_qualifiers
      @all_qualifiers ||= self.class.qualifiers + @dynamic_qualifiers
    end

    # 
    # Retrieve a list result set. Accepts an ordered list of columns to include
    # in the result set. Returns an enumerable list of results. Each result item 
    # is a struct with columns ordered the same as column_names. Columns 
    # specified in column_names that are not configured in the list will be excluded.
    # 
    # column_names: Array of columns to retrieve. 
    # options: 
    #  * :page - (default 1)
    # 
    #  * :page_size - Page size. Set to 0 or nil to retrieve all rows. (default 35)
    # 
    #  * :filters - A hash of filters to apply, keyed by column names.
    #               Values for default filters are free text. For declared
    #               filters, the value should match the :value from the 
    #               filter definition (see ::column). (default {})
    #  
    #  * :sorts - An array of strings containing the column name and sort 
    #             direction. The sort direction should match "asc", "ASC",
    #             "desc" or "DESC"
    #             ex: ["col_1 asc", "my_attr DESC"]
    # 
    def evaluate(column_names, options={})
      options = {
        :page => 1, 
        :page_size => 35, 
        :filters => {},
        :sorts => []
      }.merge(options)

      included_columns = column_names.collect{|c| col = all_columns[c.to_sym]}.compact
      list_columns = included_columns.collect(&:to_sql)

      included_joins = all_join_dependencies(included_columns)
      list_joins = included_joins.collect(&:to_sql)
      
      list_qualifiers = all_qualifiers.collect(&:to_sql)

      list_filters = all_filter_fragments(options[:filters])
      
      list_sorts = all_sort_fragments(options[:sorts])

      evaluate_list_query(list_columns, list_joins, list_qualifiers, list_filters, list_sorts, options[:page], options[:page_size])
    end

    private

    def self.columns
      @columns ||= {}
    end

    def self.joins
      @joins ||= {}
    end

    def self.qualifiers
      @qualifiers ||= []
    end

    def evaluate_list_query(fields, joins, qualifiers, filters, sorts, page, page_size)
      page = page.nil? ? 1 : page.to_i
      page_size = page_size.to_i unless page_size.nil?
      filter = filters.blank? ? '' : "WHERE (#{filters.join(') AND (')})"
      sorting = sorts.blank? ? '' : "ORDER BY #{sorts.join(', ')}"
      paging = (page_size.nil? || page_size == 0 ) ? '' : "LIMIT #{page_size} OFFSET #{(page - 1) * page_size}"

      results = ActiveRecord::Base.connection.select_all(<<-SQL.unindent(true))
        SELECT *, count(*) OVER() AS total_row_count FROM (
          SELECT #{fields.join(",\n         ")}
          FROM #{self.class.table_name}
          #{joins.join("\n  ")}
          WHERE #{qualifiers.join("\n    AND ")}
        ) AS intermediate_result
        #{filter}
        #{sorting}
        #{paging}
      SQL
      
      total_rows = results.blank? ? 0 : results.first['total_row_count'].to_i
      prepare_result_set(results, page, page_size, total_rows, [:total_row_count])
    end

    # Determine dependencies & order based on requested columns
    def all_join_dependencies(columns)
      required = columns.collect(&:join_dependencies).flatten.uniq
      required += all_qualifiers.collect(&:join_dependencies).flatten.uniq

      jd = JoinDependencies.new(all_joins, required)
      jd.tsort
    end

    def all_sort_fragments(sorts=[])
      sorts.inject([]) do |a, s| 
        col_name, direction = s.split(' ')
        sort_col = all_columns[col_name.to_sym]
        next a if sort_col.nil?
        descending = (direction.casecmp("DESC") == 0)
        a << sort_col.sort_sql(descending)
      end
    end

    def all_filter_fragments(filters={})
      return [] if filters.blank?
      grouped = Hash.new {|h,k| h[k] = [] }
      filters.each do |k,v|
        filter_col = all_columns[k.to_sym]
        next if filter_col.nil?
        grouped[filter_col.filter_group] << filter_col.filter_sql(v)
      end
      fragments = grouped[nil]
      grouped.each do |k,v|
        next if k.nil?
        fragments << "(#{grouped[k].join(' OR ')})"
      end
      fragments
    end

    # Strip out overhead columns and perform typecasting
    def prepare_result_set(results, page, page_size, total, strip_columns=[])
      if page_size.nil? || page_size == 0
        page = 1
        page_size = total
      end
      prepared = ConfigurableList::Collection.new(page, page_size, total)
      unless results.blank?
        attributes = results.first.keys.collect{ |k| k.to_sym }
        attributes -= strip_columns
        attr_struct = Struct.new(*attributes) 
        results.each do |row|
          result_row = attr_struct.new
          row.each do |k,v|
            col_name = k.to_sym
            next unless attributes.include?(col_name)
            column = all_columns[col_name]
            next if column.nil?
            result_row[k] = column.type_cast(v)
          end
          prepared << result_row
        end
      end
      prepared
    end

    # Hacking this method in since this isn't an ActiveRecord subclass
    def sanitize_sql_array(array)
      ActiveRecord::Base.send("sanitize_sql_array", array)
    end

  end

end