module OJS
  module Loader
    class DefaultResource
      @@for_file_path = {}
      attr_reader :file_path, :created_at, :included_prerequisite_resources
      def initialize(file_path)
        @file_path = file_path
        @@for_file_path[file_path] = self
        @included_prerequisite_resources = []
        @created_at = Time.now
        @prerequisite_files = []
      end
      def prerequisite_files
        @prerequisite_files
      end
      def add_prereq(path)
        @prerequisite_files << path
      end
      def content
        source
      end
      def size
        content.size
      end
      def name
        file_path.basename.to_s
      end
      def pack_type
        @file_path.extname[1..-1]
      end
      def source
        @file_path.read
      end
    end
  end
end