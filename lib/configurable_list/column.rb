module ConfigurableList

  class Column

    module Format
        ISO_DATETIME = /\A(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)(\.\d+)?\z/
        TRUE = "TRUE"
        FALSE = "FALSE"
    end

    attr_reader :name, :sql_property, :datatype, :join_dependencies, :filters, 
                :disable_filter, :filter_group, :human_name

    def initialize(name, sql_property, options={})
      options = {
        :datatype => :string,
        :require_join => [],
        :filter => "ILIKE '%%%s%%'",
        :filters => nil,
        :disable_filter => false,
        :filter_group => nil, 
        :sort_nulls_last => true,
        :human_name => nil,
        :format => nil
      }.merge!(options)
      @name, @sql_property, @options = name.to_sym, sql_property, options
      @datatype = options[:datatype]
      @join_dependencies = [*options[:require_join]]
      @filter = options[:filter]
      @filters = validate_filters(options[:filters])
      @human_name = options[:human_name] # || name.to_s.gsub(/_/,' ').titleize
      @disable_filter = options[:disable_filter]
      @filter_group = options[:filter_group]
      @nulls_last = options[:sort_nulls_last]
      @format = options[:format]
    end

    def to_sql
      "#{sql_property} AS #{name.to_s}"
    end

    def sort_sql(descending=false)
      direction = descending ? "DESC" : "ASC"
      nulls = @nulls_last ? " NULLS LAST" : ""
      "#{name.to_s} #{direction}#{nulls}"
    end

    def filter_sql(value=nil)
      unless disable_filter
        if (filters.nil?)
          # Free text or option-driven filters
          # Value must be escaped since it comes in off the browser and can't be validated against configuration.
          comp_string = @filter.is_a?(Proc) ? @filter.call(value) : @filter
          sanitize_sql_array(["#{name.to_s} #{comp_string}", value])
        else
          # Configured filters
          filter = filters.detect{ |f| f[:value] == value }
          return "1=1" if filter.nil?
          condition = filter[:condition]
          comp_string = condition.is_a?(Proc) ? condition.call : condition.to_s
          "#{name.to_s} #{comp_string}"
        end
      end
    end

    # Return the filter value for the given display value (:human_name if provided, otherwise :value)
    def filter_value_matching(value)
      @filters.each do |f|
        match = f[:human_name] || f[:value]
        return f[:value] if match == value
      end
    end

    # Inspired by (boosted from?) ActiveRecord::ConnectionAdapters::Column
    def type_cast(value)
      return nil if value.nil?
      case @datatype
        when :string    then value
        when :integer   then value.to_i rescue value ? 1 : 0
        when :float     then value.to_f
        when :datetime  then parse_time(value)
        when :boolean   then parse_boolean(value)
        else value
      end
    end

    def humanize(value)
      if @format.is_a?(String) && value.present?
        sprintf(@format, value) 
      elsif @format.is_a?(Proc)
        @format.call(value)
      else
        value
      end
    end

    protected

    # Doesn't handle time zones.
    def parse_time(value)
      if value =~ Format::ISO_DATETIME
        microsec = ($7.to_f * 1_000_000).to_i
        Time.time_with_datetime_fallback(ActiveRecord::Base.default_timezone, 
                                         $1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, $6.to_i, microsec) rescue nil
      else
        raise "Couldn't parse datetime value (#{value})"
      end
    end

    def parse_boolean(value)
      value == Format::TRUE
    end

    def validate_filters(filters)
      return filters if filters.nil? || filters.is_a?(Symbol)
      filters.each do |f|
        unless (f.is_a?(Hash) && 
                ([:value, :condition] - f.keys).empty? && 
                f[:value].is_a?(String) && 
                (f[:condition].is_a?(String) || f[:condition].is_a?(Proc)))
          raise "Filters should be of the form: { :value => String, :condition => [String|Proc], :human_name => String, :display_suffix => String }. :human_name and :display_suffix are optional."
        end
      end
      filters
    end

    # Hacking this method in since this isn't an ActiveRecord subclass
    def sanitize_sql_array(array)
      ActiveRecord::Base.send("sanitize_sql_array", array)
    end

  end

end