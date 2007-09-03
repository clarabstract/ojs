require 'haml'
module OJS
  module Loader
    class SassResource < DefaultResource
      def content
        unless  @compiled_css && @last_compile > file_path.mtime
          time = Benchmark.measure do
            @compiled_css = Sass::Engine.new(source).render
            @last_compile = Time.now
          end
          RAILS_DEFAULT_LOGGER.info "Compiled SASS #{name} in #{"%.4fs" % time.real}."
        end
        @compiled_css
      end
      def pack_type
        "css"
      end
    
    end
  end
end