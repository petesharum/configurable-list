Configurable List
-----------------

Configurable List is a small library for creating and evaluating very flexible Postgres queries to back a user-configurable table. This is arguably "doing it wrong" and isn't likely to make it into production code. But it was an interesting exercise, so I'm hanging on to it for a while.

**Features:**  
  Configurable columns  
  Configurable column ordering  
  Configurable joins required for columns or for other joins: Configurable List manages the dependencies and assembles the query correctly   
  Configurable qualifiers  
  Columns, joins and qualifiers can be determined at the class level or at runtime at the instance level  
  Filters   
  Sorts  
  Paging  

Subclasses ConfigurableList::List to define the behavior of a "Configurable List View." Columns, column ordering, sorts, filters and paging are supported.

Columns, joins and qualifiers can be defined at the class or instance level. Once instantiated, an object of a List subclass type can be used to retrieve list data or to supply configuration options to a list configuration UI. 

Join dependencies can be specified with the :require_join property on any column, qualifier or join. Join dependency ordering is handled automatically. 

**Example usage:**

This is a basic example of some of the features. For full information on various options, see the comments in ConfigurableList::List.

    class MyList < ConfigurableList::List

      base_table 'comments'

      # basic column
      # supported types are :string (default), :integer, :float, :datetime and :boolean.  
      column :comment, 'comments.body', :datatype => :string
      column :created_at, 'comments.created_at', :datatype => :datetime, :require_join => :comments

      # columns can come from joined columns
      column :name, 'users.name', :datatype => :string, :require_join => :users
      join :users, 'INNER JOIN users ON comments.user_id = users.id'

      # joins can require other joins
      join :accounts, 'INNER JOIN accounts ON accounts.id = users.account_id', :require_join => :users

      # qualifiers get appended to the WHERE clause
      qualifier 'users.active = 1'

      # columns, joins and qualifiers can also be added once our list is instantiated
      def initialize(user)
       add_column :account_name, 'accounts.name', :datatype => :string, :require_join => :admin_profiles if user.admin?
       add_join :admin_profiles, 'LEFT OUTER JOIN admin_profiles ON admin_profiles.user_id = user.id', :require_join =>:users   
       add_qualifier sanitize_sql_array(["users.id = ?",user.id]), :require_join => :users
      end

    end

    
    list = MyList.new(user)

    list.display_columns do |col|
      puts col.human_name
      puts col.datatype
    end

    results = list.evaluate([:name, :comment], :page => 1, :page_size => 50, :filters => { :comment => 'football' }, sorts => 'name asc')

    # evaluation results is an enumerable list of matches
    results.each {|item| puts item.name }

    # accessors are also available for page, page_size and total rows
    results.page       # 1
    results.page_size  # 50
    results.total_rows # 235

    # and a few conveniences for front-end pagination controls
    results.total_pages    # 5
    results.out_of_bounds? # false
    results.offset         # 0
    results.previous_page  # nil
    results.next_page      # 2
  
  
**Advanced Column Options:**

*:filter*  
Filter SQL sprintf string or a proc that accepts the valueand returns a sprintf string (default `"ILIKE '%%%s%%'"`).

*:filters*  
By default columns support filters with an ILIKE clause. Specify filters with an array to declare a set of supported filters (to use in a `<SELECT>` element for example). Each element should be a hash:
> `{ :value => '1', :condition => "<= 0", :human_name => "Overdue", :dislpay_suffix => "[12]" }` 

  `:value` must be a string.  
  `:condition` can be either a string qualifier or a proc that returns a string qualifier.  
  `:human_name` is optional.  
  `:display_suffix` is optional.  
An exception will be raised for filters do not meet data type requirements.

*:disable_filter*  
Disallow filters on this column (default false).

*:filter_group*  
By default all filters are exclusive (they are joined together in the query by `"AND"`). Filters on columns with the same `:filter_group` value are inclusive. They are joined by `"OR"` before joining to other specified filters with `"AND"`.

*:sort_nulls_last*  
Always sort nulls to the end (default true)

*:human_name*  
Gives the column a human name for it to be identified in `#display_columns`. Can also be used later in a configuration UI. 