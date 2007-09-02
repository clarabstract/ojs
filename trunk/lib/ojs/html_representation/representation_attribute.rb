module OJS
  module HtmlRepresentation
    class RepresentationAttribute
      include TagBuilder
      attr_reader :name
      def initialize(name, parent_rep, view)
        @name = name
        @representation = parent_rep
        @view = view
        clear_insertions
      end
      def set?
        !! value
      end
      # Just the attribute name unless html_name_prefix is set (usually via the name_group configurator on the parent rep),
      # in which case names are prepared to yield a hash, named after the prefix, keyed by ID.
      # e.g. "name" or "people[23][name]" 
      def html_name
        if @representation.html_name_prefix
          "#{@representation.html_name_prefix}[#{@representation.data_object_id}][#{@name}]"
        else
          "#{@name}"
        end
      end
      def html_id
        "#{@representation.html_id}_#{@name}"
      end
      def html_classes
        @representation.html_classes + [@name]
      end
      def value
        @representation.value_for(@name)
      end
      def url(url_req)
        @representation.url(url_req)
      end
      def as(transform_callback, *args)
        #TODO: Handle transforms for templates
        transformed_value = @view.send( *([transform_callback, self.value] + args))
        TransformedRepresentationAttribute.new(transform_callback, transformed_value, self, @representation, @view)
      end
      def event_callback_name(event_name)
        "on_#{@name}_#{event_name}"
      end
    end
  end
end