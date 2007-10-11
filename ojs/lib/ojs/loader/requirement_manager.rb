require 'yaml'

module OJS
  module Loader
    class RequirementManager
      def initialize
        @page_requirements = {}
        @resource_cache = {}
      end
      def page_requirements(page_name)
        @page_requirements[page_name] ||= PageRequirement.new(page_name, self)
      end
      def page_requirements_for(pack_type)
        prf = {}
        @page_requirements.each_pair do |key, page_req|
          prf[key] = page_req.resources_with_pack_type(pack_type)
        end
        prf
      end
      def packer_for(pack_type)
        Packer.new(page_requirements_for(pack_type))
      end
      def update_cache!
        @@cached = self.class.cache_store.store(self)
      end
      def resource_for(path)
        @resource_cache[path] ||= self.class.make_new_resource_for(path)
      end


      class << self
        attr_writer :cache_store
        attr_accessor :default_resource_class
        def cache_store
          @cache_store || OJS::options[:req_cache_store]
        end
        def load_from_cache
          @cached ||= (cache_store.load || self.new)
        end
        
        def register_resource_class(ext, handler_class)
          @resource_classes ||= {}
          @resource_classes[ext] = handler_class
        end
        def make_new_resource_for(path)
          if special_resource = @resource_classes[path.extname]
            special_resource.new(path)
          else
            default_resource_class.new(path)
          end
        end
      end
    end
  end
end

