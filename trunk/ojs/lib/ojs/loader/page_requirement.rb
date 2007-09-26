module OJS
  module Loader
    class PageRequirement
      def initialize(page_name, requirement_manager)
        @requirement_manager = requirement_manager
        @page_name = page_name
        @resources = {}
        demand_file(OJS::options[:always_require].last)
      end
      def resources
        @resources.values
      end
      # Add a file (and dependencies, if any) to the page requirement.
      # If multiple files are given, the last one that actually exists is used
      def demand_file(*possible_files)
        path = resolve_path(possible_files)
        unless @resources[path]
          new_resource = @resources[path] = @requirement_manager.resource_for(path)
          new_resource.prerequisite_files.each do |prerequisite_file|
            new_resource.included_prerequisite_resources << demand_file(prerequisite_file) unless OJS::options[:never_require].include?(prerequisite_file)
          end
        end
        @resources[path]
      end
      def resources_with_pack_type(type)
        resources.select{|r| r.pack_type == type}
      end
      
      def resolve_path(possible_files)
        path = nil
        possible_files.each do |file|
          file = Pathname.new(file)
          unless file.exist?
            path = Pathname.new(OJS::options[:base_paths][file.extname].to_s) + file unless !path.nil? && path.exist?
          end
        end
        raise "Couldn't require #{possible_files.join(", or ")}" unless path.exist?
        path
      end

      def known_pack_types
        resources.collect(&:pack_type).uniq
      end
      def get_packages
        known_pack_types.inject([]) do |pack_acc, pack_type|
          pack_acc + @requirement_manager.packer_for(pack_type).packs_for(@page_name)
        end
      end
    end
  end
end