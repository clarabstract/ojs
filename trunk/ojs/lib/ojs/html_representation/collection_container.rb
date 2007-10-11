module OJS
  module HtmlRepresentation
    class CollectionContainer < RepresentationAttribute
      def initialize(name, representation, view)
        @partial = name || representation.name.to_s.singularize
        @name = name || "collection"
        @representation = representation
        @view = view
        clear_insertions
      end
      def value
        @representation.value[:collection_content] rescue @view.render :partial=> @partial, :collection=>collection_array
      end
      private
      def collection_array
        if @representation.value.nil? then [] else @representation.value.to_ary end
      end
    end
  end
end