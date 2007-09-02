require 'tsort'
module OJS
  module Loader
    class Package
      attr_reader :resources
      def initialize(resources)
        @resources = resources
        write_package_file
      end
      # Ensure dependency order using topographical sorting
      include TSort
      def tsort_each_node(&block)
        resources.each(&block)
      end
      def tsort_each_child(resource, &block)
        resource.included_prerequisite_resources.each(&block)# if resource
      end
      alias_method :tsorted_resources, :tsort
      def write_package_file
        unless empty?
          File.open(pack_file_path, "w") do |file_stream|
            tsorted_resources.each do |resource|
              file_stream.puts "/* #{resource.name} */"
              file_stream.puts resource.content
            end
          end
        end
      end
      def include?(what)
        @resources.include?(what)
      end
      def pack_type
        @resources.first.pack_type
      end
      def output_path
        Pathname.new(OJS::options[:pack_output][pack_type])
      end
      def pack_file_path
        output_path + Pathname.new("pack#{unique_name}.#{pack_type}")
      end
      def unique_name
        @resources.collect(&:content).hash
      end
      def public_path
        pack_file_path.relative_path_from(Pathname.new(OJS::options[:pub_root]))
      end
      def to_include_tag
        if pack_type == "js"
          %{<script src="/#{public_path}" type="text/javascript"></script>}
        else
          %{<link href="/#{public_path}" media="screen" rel="Stylesheet" type="text/css" />}
        end
      end
      def empty?
        @resources.empty?
      end
      def to_s
        "<#{self.class.name}: #{tsorted_resources.collect{|r|r.name}.join(', ')}>"
      end
    end
  end
end