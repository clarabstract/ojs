module OJS
  module HtmlRepresentation
    # Expects included to implement:
    # - data_object_is_new? 
    # - html_id
    # - html_classes
    # - html_name
    # - url(url)
    # - js_controller(method, *params)
    module TagBuilder
      # Accepts :url, :multipart and :method as other rails helpers do
      # :url will be assumed to be the #{for_obj_class}_url 
      def form(*args, &block)
        content, options = splat(args, block)
        options[:method] ||= default_method
        options[:action] = url(options.delete(:url))
        options[:enctype] = "multipart/form-data" if options.delete(:multipart)

        unless [:post, :get].include?(options[:method])
          before_content @view.hidden_field_tag("_method", options[:method])
          options[:method] = :post
        end
        options.merge!(event_hooks(false, :submit))
        tag :form, content, options, block
      end
      def label(*args, &block)
        content, options = splat(args, block)
        content ||= name.to_s.humanize
        options[:for] ||=  html_id
        options[:_id] ||= "lbl"
        tag :label, content, options, block
      end
      def text_area(*args, &block)
        content, options = splat(args, block)
        field_tag :textarea, content, options, block
      end
      
      HTML_TAGS = %w(
        a abbbr acronym address area b base bdo big blockquote br button caption cite code col colgroup dd del dfn div dl
        dt em fieldset frame frameset h1 h2 h3 h4 h5 h6 hr i iframe img input ins kbd legend li link map meta
        noframes noscript object ol optgroup option p param pre q samp script select small span strike strong style sub sup 
        table tbody td textarea tfoot th thead tr tt ul var
      )
      
      HTML_TAGS.each do |tag|
        module_eval %Q{def #{tag} (*args, &block); content, options = splat(args, block); tag(:#{tag}, content, options, block); end }, __FILE__, __LINE__
      end
        
      
      def text_field(*args, &block)
        input_tag :text, args, block
      end
      def password_field(*args, &block)
        input_tag :password, args, block
      end
      def hidden_field(*args, &block)
        input_tag :hidden, args, block
      end
      def file_field(*args, &block)
        input_tag :file, args, block
      end

      # :checked_value and :unchecked value, implemented with hidden field (much like check_box helper)
      def check_box(*args, &block)
        content, options = splat(args, block)
        options[:checked_value] ||= "1"
        options[:unchecked_value] ||= "0"
        options[:value] = options.delete(:checked_value)
        options[:_class] = options[:type] = :checkbox
        after_tag hidden_field(options.delete(:unchecked_value), :_id=>'unchecked')
        field_tag(:input, nil, options, block)
      end
      
      # Block form (simple tag passthrough, erb capture for options html )
      #   select(tag_options = {}) {|self| ... }
      #
      # Non-block:
      #   select( values = nil, tag_options = {} )
      #   select( *values, tag_options={}) (for more then 1 value)
      #
      # Values:
      #   [String]          simply pass html content
      #   [Hash]            opt_value => opt_content
      #   [Array]           opt_content only (no value attrib in option tag)
      #   [Representation]  TODO
      #   [nil]             use self.value
      #
      # tag_options:
      #   [:selected]       The value to be selected by default.
      #                     If values are an array, this can be a Numeric index for the value. Left blank it will assume the first value.
      #                     If value are a hash, this can be a Symbol key for the value.
      #                     If no value matches, and it's a string - an <option> will be created for it.
      def select(*args, &block)
        if block
          content = @view.capture(&block)
          raise ArgumentError, "too many arguments for select() in block form (#{args.size} for 1)" if args.size > 1
          tag_options = args.first || {}
        else
          if args.size > 2
            tag_options = args.last.is_a?(Hash) ? args.pop : {}
            values = args
          else
            if args[1].is_a?(Hash)
              tag_options = args[1]
              values = args[0] || self.value
            else
              tag_options = {}
              values = args
            end
          end
          selected = tag_options.delete(:selected)
          selected_option = false
          content = case values
          when String
            raise ArgumentError, ":selected option doesn't work with string content" if selected
            values
          when Array
            selected = values[selected] if selected.is_a?(Numeric)
            values.inject("") do |acc, val|
              selected_option = (selected == val)
              acc << option(val, nil, selected_option)
            end
          when Hash
            selected = values[selected] if selected.is_a?(Symbol)
            values.inject("") do |acc,tpl|
              selected_option = (selected == tpl[1])
              acc << option(tpl[1], tpl[0], selected_option)
            end
          else
            raise ArgumentError, "don't know how to make option tags out of #{value.inspect}"
          end
        end
        selected_value = values.is_a?(Array) ? "default" : nil
        content = option(selected, selected_value , true) + content if !selected_option && selected.is_a?(String) 
        
        field_tag(:select, content , tag_options, block)
      end
      
      def option(content, value, selected)
        options = {}
        options[:value] = value if value
        options[:selected] = "selected" if selected
        @view.send(:content_tag_string, :option, content, options)
      end
      
      def submit(*args, &block)
        content, options = splat(args, block)
        options[:_loading_text] = options.delete(:loading_text) if options[:loading_text]
        options[:type] ||= "submit"
        options[:_id] = "submit"
        options[:value] = content || "Submit"
        field_tag(:input, nil, options, block)
      end
      
      def image_submit(*args, &block)
        content, options = splat(args, block)
        options[:type] ||= "image"
        options[:_id] = "submit"
        options[:alt] ||= "Submit"
        options[:src] = content
        field_tag(:input, nil, options, block)
      end
      
      def link(*args, &block)
        content, options = splat(args, block)
        options[:href] = url(options.delete(:url))
        tag(:a, content, options, block)
      end
      # An ajax link
      def action(*args, &block)
        content, options = splat(args, block)
        options[:method] ||= default_method
        options[:remote_method] = options.delete(:method) #can't neatly call it 'method' because Opera is on CRACK
        link(content, options, &block)
      end
      # Using links as "buttons" (i.e. don't go nowhere)
      def command(*args, &block)
        content, options = splat(args, block)
        options[:url] = "##{name}"
        options[:command] = "command"
        link(content, options, &block)
      end
      def email_link(*args, &block)
        content, options, email = splat(args, block)
        options[:href] = "mailto:#{email || value}"
        tag(:a, content, options, block)
      end
 
      def loading_indicator(*args, &block)
        content, options = splat(args, block)
        options[:alt] ||= "loading"
        options[:_id] = "loading_indicator"
        options[:style] ||= ""
        options[:style] += ";display:none;"
        options[:src] = @view.image_path("loading.gif")
        tag(:img, content, options, block)
      end
      
      private
      def default_method
        data_object_is_new? ? :put : :post
      end
      def splat(args, block)
        if args.last.is_a? Hash
          options = args.pop
        else
          options = {}
        end
        if block
          content = @view.capture(self,&block)
        else
          content = args.pop
        end
        return [content, options, *args]
      end
      
      def event_hooks(pass_value, *events)
        handlers = {}
        events.each do |event|
          # handlers["on#{event}"] = "callback($(this).controller(), '#{event_callback_name(event)}', [this, event#{", $F(this)" if pass_value}]); return true;"
          handlers["on#{event}"] = "return $(this).handle(event)"
        end
        handlers
      end
      
      SELF_CLOSING_TAGS = %w(area base br col frame hr img input link meta param)
      
      def tag(name, content, options, block)
        content ||= (self.value || self.name.to_s.humanize) unless SELF_CLOSING_TAGS.include?(name.to_s.downcase)
        content = wrap_content(content)
        options[:id] = [html_id, options[:_id]].compact.join('_')

        options[:class] = (html_classes + [options[:class], options.delete(:_id), options.delete(:_class)].flatten).compact.join(' ')
        
        html = @view.send(:content_tag_string, name, content, options)
        html = wrap_tag(html)
        if block
          @view.concat(html, block.binding)
        else
          return html
        end
      end
      
      def field_tag(name, content, options, block)
        options[:name] ||= html_name
        options.merge!(event_hooks(true, :change, :blur, :focus))
        tag(name, content, options, block)
      end
      
      def input_tag(type, args, block)
        content, options = splat(args, block)
        options[:type] = type
        options[:value] ||= (content || self.value || options[:empty])
        options[:_class] = type.to_s
        if options[:empty] && (!content || !value)
          options[:_class] << " empty"
        end
        field_tag(:input, nil, options, block)
      end
      def wrap_tag(html)
        @before_tag.to_s + html + @after_tag.to_s
      end
      def wrap_content(content)
        @before_content.to_s + content.to_s + @after_content.to_s
      end
      
      def clear_insertions
       @before_tag, @after_tag, @before_content, @after_content = '','','',''
      end
      
      def before_tag(insertion)
        @before_tag << insertion
      end
      def after_tag(insertion)
        @after_tag << insertion
      end
      def before_content(insertion)
        @before_content << insertion
      end
      
      def after_content(insertion)
        @after_content << insertion
      end    
    end
  end
end