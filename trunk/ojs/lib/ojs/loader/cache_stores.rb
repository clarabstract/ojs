require 'yaml'
module OJS
  module Loader
    module CacheStores
      class MarshalStore
        def initialize(cache_file)
          @cache_file = cache_file
        end
        def load
          return nil unless File.exists? @cache_file
          RAILS_DEFAULT_LOGGER.debug "Loading RequirementManager from cache #{@cache_file}"
          File.open(@cache_file, "r") do |stream|
            Marshal.load(stream.read)
          end
        rescue ArgumentError => e
            if e.message =~ /^undefined class\/module ([^\s]+)/
              $1.constantize
              retry
            end
            raise e
        end
        def store(obj)
          RAILS_DEFAULT_LOGGER.debug "Stored RequirementManager in cache #{@cache_file}"
          File.open(@cache_file, "w") do |stream|
            stream.write(Marshal.dump(obj))
          end
          obj
        end
      end
      # Uses MarshalStore but also dumps an easy to inspect yaml file for debugging.
      class MultiStore < MarshalStore
        attr_reader :cache_file, :yaml_cache_file
        def initialize(cache_file)
          @cache_file = cache_file
          @yaml_cache_file = cache_file.sub(/\.\w+\Z/,".yaml")
        end
        def store(obj)
          File.open(@yaml_cache_file, "w") do |stream|
            stream.write(YAML.dump(obj))
          end
          super(obj)
        end
      end
=begin
      # Does not load properly
      class YamlStore
        def initialize(cache_file)
          @cache_file = cache_file
        end
        def load
          return nil unless File.exists? @cache_file
          File.open(@cache_file, "r") do |stream|
            YAML.load(stream.read)
          end
        end
        def store(obj)
          File.open(@cache_file, "w") do |stream|
            stream.write(YAML.dump(obj))
          end
          obj
        end
      end
=end
    end
  end
end