Configurable List
-----------------

Configurable List is a small library for creating and evaluating very flexible Postgres queries to back a user-configurable table. This is arguably "doing it wrong" and isn't likely to make it into production code. But it was an interesting exercise, so I'm hanging on to it for a while.

**Features:**

*  Configurable columns

*  Configurable column ordering

*  Configurable joins required for columns or for other joins: Configurable List manages the dependencies and assembles the query correctly 

*  Configurable qualifiers 

*  Columns, joins and qualifiers can be determined at the class level or at runtime at the instance level

*  Filters 

*  Sorts

*  Paging 

Subclasses of List can be created to define the behavior of a "Configurable List View." Columns, column ordering, sorts, filters and paging are supported.

Columns, joins and qualifiers can be defined at the class or instance level. Once instantiated, an object of a List subclass type can be used to  retrieve list data or to supply configuration options to a list configuration UI. 

Join dependencies can be specified with the :require_join property on any column,  qualifier or join. Join dependency ordering is handled automatically. 

__TODO:__ Example usage