module OJS
  module Loader
    class TemplateResource < DefaultResource
      def content
        unless  @compiled_template && @last_compile > file_path.mtime
          time = Benchmark.measure do
            translation = OJS::OjsLanguage::Translation.new(source, OJS::OjsLanguage::LanguageDefinition)
            placeholder = Hash.new{|hash, key| "###{key}##" }
            placeholder[:id] = '##id##'
            placeholder[:collection_content] = '##collection_content##'
            @compiled_template = make_js_template(self.class.view.controller.send(:render_to_string, :partial => partial_path, :object=>placeholder))
            @last_compile = Time.now
          end
          RAILS_DEFAULT_LOGGER.info "Compiled template #{name} to JS in #{"%.4fs" % time.real}."
        end
        @compiled_template
      end
      def pack_type
        "js"
      end
      
      private
      
      def partial_path
        # raise "PATH: #{Pathname.new(ActionController::Base.view_root)}\nFILE: #{@file_path}\nFILE2: #{file_path}"
        last, *path_parts = *@file_path.realpath.relative_path_from(Pathname.new(ActionController::Base.view_root)).to_s.sub(/\.\w+$/,'').split(File::SEPARATOR).reverse
        last.sub!(/^\_/,'')
        (path_parts.reverse + [last]).join(File::SEPARATOR)
      end
      def make_js_template(content)
        "function #{name.gsub(/(\.\w+$|^_)/,'')}_template(p) {return #{content.to_json.gsub(/##(\w+)##/, %q!"+_t(p,'\1')+"!)}}"
      end
      class << self
        attr_accessor :view
      end
    end
  end
end