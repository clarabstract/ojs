module OJS
  module Loader
    class OjsResource < DefaultResource
      def content
        translation_result
      end
      def prerequisite_files
        (translation_data[:class_deps] - translation_data[:classes]).collect{|class_name| class_name.underscore+".ojs"} + 
        translation_data[:file_deps] + 
        @prerequisite_files
      end
      def pack_type
        "js"
      end
      
      private
      
      def translation_result
        update_translation
        @translation_result
      end
      def translation_data
        update_translation
        @translation_data
      end
      def update_translation
        unless  @translation_result && @last_translation > file_path.mtime
          time = Benchmark.measure do
            translation = OJS::OjsLanguage::Translation.new(source, OJS::OjsLanguage::LanguageDefinition)
            @translation_result = translation.translate!
            @translation_data = translation.data
            @last_translation = Time.now
          end
          RAILS_DEFAULT_LOGGER.info "Translated #{name} in #{"%.4fs" % time.real}."
        end
      end
    end
  end
end