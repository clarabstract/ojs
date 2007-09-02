module OJS
  module RenderRepresentation
    def render_with_representation(*args, &block)
      #TODO: make assistant methods to fix repetition
      
      if (options = args.first).is_a?(Hash) && options[:representation]
        render_options = { :partial => (options[:partial] || options[:representation]) }
        json = (options[:json] || {})
        if options[:with].is_a?(Array)
          render_options[:collection] = options[:with]
          new_objects = options[:with]
        else
          new_objects = [options[:with]]
          json[:element] = "#{options[:representation]}_#{options[:with].id}"
        end
        (options[:other_elements] || {}).each_pair do |key, element|
          if element.is_a?(Array)
            json[key] = element.collect{|obj| "#{options[:representation]}_#{obj.id}"}
          else
            json[key] = "#{options[:representation]}_#{element.id}"
          end
        end
        json[:elements] = new_objects.collect{|obj| "#{options[:representation]}_#{obj.id}"}
        response.headers['X-JSON'] = json.to_json
        puts response.headers['X-JSON']
        puts "render_options: #{render_options.inspect}"
        render render_options
      else
        render_without_representation( *args, &block)
      end
    end

    
  end
end