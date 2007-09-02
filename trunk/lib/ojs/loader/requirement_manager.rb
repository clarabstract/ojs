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
          new_resource = if special_resource = @resource_classes[path.extname]
              special_resource.new(path)
            else
              default_resource_class.new(path)
            end
          if (ar_idx = OJS::options[:always_require].index(path.basename.to_s)) && ar_idx > 0
            new_resource.add_prereq OJS::options[:always_require][ar_idx - 1]
          end
          new_resource
        end
      end
    end
  end
end

if $0 == __FILE__
class Module
  def cache_method(*methods)
    methods.each do |method|
      method = method.to_s
      alias_method "__memoized__#{method}", method
      module_eval <<-EOF
        def #{method}(*a, &b)
          (@__memoized_#{method}_cache ||= {})[a] ||= __memoized__#{method}(*a, &b)
        end
      EOF
    end
  end
end

module Enumerable
  unless method_defined? :counts
    def counts
       k=Hash.new(0)
       self.each{|x| k[x]+=1 }
       k
    end
  end
  unless method_defined? :max_by
    def max_by
      max{|a,b| yield(a) <=> yield(b)}
    end
  end
end

class String
  unless method_defined? :underscore
    def underscore
      self.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
    end
  end
end

module OJS
  class <<self
    attr_accessor :options
    def configure(options)
      self.options ||= {}
      self.options.merge!(options)
    end
  end
end

require 'yaml'
require 'page_requirement.rb'
require 'cache_stores.rb'
require 'resource_factory.rb'
require 'default_resource.rb'
require 'ojs_resource.rb'
require 'packer.rb'
require 'package.rb'
require '../../language_extender.rb'
require '../../language_extender/tree_writer_helper.rb'
require '../../language_extender/translation'
require '../../language_extender/language_definition'
require '../../language_extender/scope'
require '../../language_extender.rb'
require '../../language_extender/tree_writer_helper.rb'
require '../../language_extender/translation'
require '../../language_extender/language_definition'
require '../ojs_language/translation'
require '../ojs_language/language_definition'
RAILS_ROOT = "/Users/ruy/Projects/inthex"

module OJS
  class << self
    attr_accessor :options
  end
end
OJS::options = ({
  :base_paths=>{
    ".ojs" => "#{RAILS_ROOT}/app/javascript",
    ".js" => "#{RAILS_ROOT}/public/javascripts/lib",
    ".css" => "#{RAILS_ROOT}/public/stylesheets"
  },
  :pack_output => {
    "js" => "#{RAILS_ROOT}/public/javascripts/packs",
    "css" => "#{RAILS_ROOT}/public/stylesheets/packs",
  },
  :pub_root => "#{RAILS_ROOT}/public",
  :req_cache_store => OJS::Loader::CacheStores::YamlStore.new("#{RAILS_ROOT}/tmp/ojs_req_cache.yaml"),
  :always_require => %w(prototype.js class.js event_dispatcher.js),
  :base_class => 'Base'
})

OJS::Loader::ResourceFactory.default_resource_class = OJS::Loader::DefaultResource
OJS::Loader::ResourceFactory.register_resource_class(".ojs", OJS::Loader::OjsResource)

rm = OJS::Loader::RequirementManager.new()
pr = rm.page_requirements("list/all")
pr.demand_file("torrents/new.css")
pr.demand_file("torrents/show.css")
pr.demand_file("edit_invitation.ojs", "invitation.ojs")
pr.demand_file("class.js")
pr.demand_file("entries/index.css")
pr.demand_file("invitations/index.css")
fb = rm.page_requirements("foo/bar")
fb.demand_file("torrents/show.css")
fb.demand_file("class.js")
fb.demand_file("entries/index.css")
fb.demand_file("invitations/index.css")
blah = rm.page_requirements("what/ever")
blah.demand_file("class.js")
blah.demand_file("invitations/index.css")
meep = rm.page_requirements("meep/meep")
meep.demand_file("class.js")
meep.demand_file("invitations/index.css")
beep = rm.page_requirements("beep/beep")
beep.demand_file("class.js")
beep.demand_file("invitations/index.css")
puts rm.to_yaml
puts "\nPACKER(js):-------------------\n"
puts rm.packer_for('js').to_yaml
puts "\nPACKER(css):-------------------\n"
puts rm.packer_for('css').to_yaml
puts "\nPACKS(js):-------------------\n"
puts rm.packer_for('js').packs.join("\n")
puts "\nPACKS(css):-------------------\n"
puts rm.packer_for('css').packs.join("\n")
puts "\nPACKS4PAGE:---------------\n"
puts pr.get_packages.join("\n")
puts "\nPACKS4PAGE2TAG:-----------\n"
puts pr.get_packages.collect{|pack| pack.to_include_tag}

=begin

module OJS
  # Manages requirements for a given page
  class ReqManager
    def initialize(page_name)
      @page_name = page_name
      self.class.cache[:reqs][@page_name] = []
    end
    def pack_files
      self.class.cache[:packs_for][page_key] || generate_new_packs
    end
    def add_requirement(file_name)
      puts("adding require: #{file_name}")
      self.class.cache[:reqs][@page_name] << file_name unless self.class.cache[:reqs][@page_name].include?(file_name)
    end
    
    private
    def page_key
      "#{@page_name}#{self.class.cache[:reqs].to_a.hash}"
    end
    def pack_file_name_for(pack)
      "#{self.class.pack_files_dir}/pack#{pack.sort.hash}.#{self.class.pack_file_ext}"
    end
    def generate_new_packs
      @proccessed = {}
      if self.respond_to? :preproccess_source
        Dir[File.join(OJS::options[:ojs_source_path],'*')].each do |f|
          @proccessed[f] = preproccess_source(f, IO.read(f))
        end
      end
      packer = Packer.new(self.class.cache[:reqs])
      packer.packs.each do |pack|
        pack = sort_pack(pack)
        pack_file = pack_file_name_for(pack)
        self.class.cache[:pack_content_fyi][pack_file] = pack
        unless File.exists?(pack_file)  && pack.any?{|file_for_pack| File.mtime(pack_file) > File.mtime(file_for_pack)}
          File.open(pack_file, "w") do |pack_file_stream|
            pack.each do |file_for_pack|
              pack_file_stream.write("//PACKING FILE: #{file_for_pack}\n")
              pack_file_stream.write(@proccessed[file_for_pack] || IO.read(file_for_pack))
              pack_file_stream.write("\n")
              pack_file_stream.write("//END OF FILE: #{file_for_pack}\n")
            end
          end
        end
      end
      page_packs = packer.packs_for(@page_name).collect{|pack| pack_file_name_for(pack)}
      self.class.cache[:packs_for][page_key] = page_packs
      self.class.save_cache
      return page_packs
    end
    def sort_pack(pack)
      pack
    end
    class << self
      def for_page(page_name)
        self.new(page_name)
      end
      
      def cache
        return @@cache if defined? @@cache
        if File.exists?(cache_file)
          @@cache = YAML::load_file(cache_file)
        else
          @@cache = {:reqs=>{},:packs_for=>{}, :pack_content_fyi=>{}}
        end
      end
      
      def save_cache
        File.open(cache_file, "w") do |out|
          YAML.dump(@@cache, out)
        end
      end

      def cache_file
        File.join(Dir.tmpdir, "req_manager.yaml")
      end
      def pack_files_dir
        File.dirname(__FILE__)
      end
      def pack_file_ext
        "pack"
      end
      
      private
      
      def create_empty_cache_file
        unless File.exists?(cache_file_path)
          
        end
      end
    end
  end
end

module OJS  
  class JsReqManager < ReqManager
    class << self
      def cache_file
        File.join(OJS::options[:req_cache_dir], "ojs_reqs.yaml")
      end
      def pack_files_dir
        OJS::options[:ojs_package_path]
      end
      def pack_file_ext
        "js"
      end
    end
    def add_dep(base_path, for_file, dep_file)
      puts "adding dependency #{dep_file} for file #{for_file}"
      @deps_for[for_file] << (dep_file = File.join(base_path, dep_file))
      if file_idx = @dep_order.index(for_file)
        if dep_idx = @dep_order.index(dep_file)
          unless dep_idx < file_idx
            @dep_order.delete(dep_file)
            @dep_order.insert(file_idx, dep_file)
          end
        else
          @dep_order.insert(file_idx, dep_file)
        end
      else
        unless  @dep_order.include?(dep_file)
          @dep_order << dep_file
        end
        @dep_order << for_file
      end
    end
    #callback
    def sort_pack(pack)
      @dep_order & pack
    end
    # callback
    def preproccess_source(fname, src)
      @deps_for ||= {}
      @deps_for[fname] = []
      @dep_order ||= []
      translation = OJS::Translation.new(src, OJS::Language)
      translated_source = translation.translate!
      translation.data[:class_deps].each do |dep|
        unless dep == OJS::options[:base_class]
          add_dep(OJS::options[:ojs_source_path], fname, dep.underscore + ".ojs")
        end
      end
      (translation.data[:file_deps] + OJS::options[:always_require]).each do |dep|
        if dep[/[^\.]+$/] == "js"
          dir = OJS::options[:js_lib_path]
        elsif
          dir = OJS::options[:ojs_source_path]
        end
        add_dep(dir, fname, dep)
      end
      translated_source
    end
  end
end

=end
end