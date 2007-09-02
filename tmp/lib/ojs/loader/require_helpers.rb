module OJS
  module Loader
    module RequireHelpers
      # Includes links to all generated packages for this page.
      def include_resources
        links_to_resources = nil
        RAILS_DEFAULT_LOGGER.info "Including resources packs:"
        time = Benchmark.measure do
          links_to_resources = ojs_page_requirements.get_packages.collect{|pack| RAILS_DEFAULT_LOGGER.info("   #{pack}"); pack.to_include_tag}
          ojs_req_manager.update_cache!
        end
        RAILS_DEFAULT_LOGGER.info "Processed resource packs in #{"%.4fs" % time.real}."
        links_to_resources
      end
        
      def require_resource(*possible_files)
        ojs_page_requirements.demand_file(*possible_files)
      end

      private
      def ojs_page_requirements
        TemplateResource.view ||= self
        ojs_req_manager.page_requirements("#{controller.controller_name}/#{controller.action_name}")
      end
      def ojs_req_manager
        RequirementManager.load_from_cache
      end
    end
  end
end
