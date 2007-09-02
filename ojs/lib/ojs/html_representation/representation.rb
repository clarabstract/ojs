module OJS
  module HtmlRepresentation
    class Representation
      include TagBuilder
      def initialize(name, object_class, data_object, view)
        @rep_name = name
        @object_class = object_class
        @data_object = data_object
        @view = view
        @attributes = {}
        @view.require_resource(*possible_ojs_file_names)
        clear_insertions
      end
      def name
        @rep_name
      end
      def possible_ojs_file_names
        ["#{@rep_name}.ojs", "#{@object_class}.ojs" ]
      end
      attr_reader :html_name_prefix
      def name_group(name)
        @html_name_prefix = name
        self
      end
      def data_object_id
        @data_object[:id] rescue "N"
      end
      def html_name
        ""
      end
      def html_classes
        [@rep_name, @object_class]
      end
      def html_id
        "#{@rep_name}_#{data_object_id}"
      end
      def event_callback_name(event_name)
        "on_#{event_name}"
      end
      def data_object_is_new?
        @data_object.respond_to?(:new_record?) && !@data_object.new_record?
      end

      def url(url_value = nil)
        prefix = ""
        if url_value.is_a? Symbol
          prefix = "#{url_value}_"
          url_value = nil
        end
        if url_value
          @view.url_for(url_value)
        else
          if data_object_is_new?
            @view.send("#{prefix}#{singular_url_method}".to_sym, @data_object)
          else
            #TODO: Handle empty template objects.
            @view.send("#{prefix}#{plural_url_method}".to_sym)
          end
        end
      end
      def [](attrib_name)
        @attributes[attrib_name] ||= RepresentationAttribute.new(attrib_name, self, @view)
      end
      def collection(partial_name = nil)
        CollectionContainer.new(partial_name, self, @view)
      end

      def value
        @data_object
      end
      def to_s
        "<#{self.class.name} (#{@rep_name}): #{@object_class} -> #{@data_object.inspect} >"
      end
      def value_for(attrib_name)
        @data_object[attrib_name.to_sym] rescue nil
      end
      private
      def singular_url_method
        "#{@object_class}_path"
      end
      def plural_url_method
        "#{@object_class.to_s.pluralize}_path"
      end
      class << self
        def reset_all
          @instances = {}
        end
        def find_or_create(name, object_class, data_object, view)
          @instances[[name, object_class,data_object]] ||= self.new(name, object_class, data_object, view)
        end
      end
    end
  end
end
