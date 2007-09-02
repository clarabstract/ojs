module OJS
  module HtmlRepresentation
    class TransformedRepresentationAttribute < RepresentationAttribute
      # include TagBuilder
      def initialize(transform_callback, transformed_value, original, representation, view)
        @transform_callback = transform_callback
        @transformed_value = transformed_value
        @original = original
        @representation = representation
        @view = view
        @name = "#{@original.name}_as_#{transform_callback}"
        clear_insertions
      end
      def value
        @transformed_value
      end
      def clear_insertions
        super
        after_tag @original.hidden_field
      end
    end
  end
end