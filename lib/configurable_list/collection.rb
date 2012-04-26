module ConfigurableList

  class Collection < Array
    attr_reader :page, :page_size, :total

    def initialize(page, page_size, total)
      @page, @page_size, @total = page, page_size, total
    end

    def total_pages
      @total_pages ||= (total / page_size.to_i).ceil
    end


    #
    # Duck-typing to WillPaginate::Collection
    #

    def out_of_bounds?
      page > total_pages
    end

    def offset
      (page - 1) * page_size
    end

    def previous_page
      (page > 1) ? (page - 1) : nil
    end

    def next_page
      (page < total_pages) ? (page + 1) : nil
    end

  end

end