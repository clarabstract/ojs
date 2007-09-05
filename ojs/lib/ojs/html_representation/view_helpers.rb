module OJS
  module HtmlRepresentation
    module ViewHelpers
      # Create a new html representation for an object. Calling with the same arguments will actually return the same object.
      #
      # Representations can be used to create a 'parent' HTML element with an id like "edit_invitation_23" or 
      # "edit_invitation_NEW". Child elements can then be created for this object's attributes (with ids like 
      # "edit_invitation_23_email").
      #
      # The +for_object+ must be a hash-like (responds to :[]) and have an :id key. (fun fact: ActiveRecord objects all do)
      # If nil, the +for_object+ is set to {:id=>'N'}
      #
      # You can also pass a symbol as the for_object, in which case it will be treated as nil, and both the representation_name
      # and the object_class will be set to it.
      #
      # The +representation_name+ is used to generate the html ids - for instance, a name of :comment will generate
      # IDs like "comment_23" and attribute ids like "comment_23_author". If blank, it is guessed to be the 'same' as the
      # partial name. (i.e. _comment.rhtml will assume :comment as the representation_name)
      #
      # The +object_class+ is used for auto-loading OJS files. e.g.
      # 
      #    rep(inv, :edit_invitation, :invitation)
      #
      # ... will try to load both edit_invitation.ojs and invitation.ojs. It will also be used to guess default action URLs, 
      # for instance, invitation_path().
      #
      # You must call a method from OJS::HtmlRepresentation::TagBuilder to actually convert a tag out of a rep. It won't return
      # anything useful on it's own.
      def rep(for_object = nil, representation_name = nil, object_class = nil)
        path_to_calling_view = caller.find{|p| p.starts_with?(base_path)}[/[^:]+/].split(File::SEPARATOR)
        
        if for_object.is_a?(Symbol)
          representation_name = for_object
          object_class = for_object
          for_object = nil 
        end
        
        representation_name ||= path_to_calling_view[-1][/_?([^.]+)/,1]

        object_class ||= 
                if for_object.nil? || for_object.is_a?(Hash) 
                  path_to_calling_view[-2].singularize
                elsif for_object.respond_to? :to_ary
                  for_object.first.class.name.underscore
                else
                  for_object.class.name.underscore
                end
                
        Representation.find_or_create(representation_name.to_s, object_class.to_s, for_object, self)
      end
    end
  end
end
