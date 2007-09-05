require 'haml'
# Fix stupidity
module Sass
  module Tree
    class ValueNode
      def initialize(value, style)
        if value =~ /^\@import (.*)/
          value = "@import url(/stylesheets/#{$1});"
        end
        @value = value
        super(style)
      end
    end
  end
end
module OJS
  module Loader
    class SassResource < DefaultResource
      def content
        unless  @compiled_css && @last_compile > file_path.mtime
          time = Benchmark.measure do
            @compiled_css = Sass::Engine.new(source, :filename => file_path.to_s, :load_paths=>[File.join(RAILS_ROOT, 'public','stylesheets')]).render
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