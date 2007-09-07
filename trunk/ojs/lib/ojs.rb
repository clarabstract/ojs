require 'set'
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

OJS::configure({
  :base_paths=>{
    ".ojs" => "#{RAILS_ROOT}/app/javascript",
    ".js" => "#{RAILS_ROOT}/public/javascripts/lib",
    ".css" => "#{RAILS_ROOT}/public/stylesheets",
    ".sass" => "#{RAILS_ROOT}/public/stylesheets",
    ".rhtml" => "#{RAILS_ROOT}/app/views"
  },
  :pack_output => {
    "js" => "#{RAILS_ROOT}/public/javascripts/packs",
    "css" => "#{RAILS_ROOT}/public/stylesheets/packs",
  },
  :pub_root => "#{RAILS_ROOT}/public",
  :req_cache_store => $__ojs_cache_store,
  :always_require => %w(prototype.js effects.js ojs_utils.js class.js),
  :never_require => %w(base.ojs)
})

OJS::Loader::RequirementManager.default_resource_class = OJS::Loader::DefaultResource
OJS::Loader::RequirementManager.register_resource_class(".ojs", OJS::Loader::OjsResource)
OJS::Loader::RequirementManager.register_resource_class(".rhtml", OJS::Loader::TemplateResource)
OJS::Loader::RequirementManager.register_resource_class(".sass", OJS::Loader::SassResource)

class ActionView::Base
  include OJS::Loader::RequireHelpers
  include OJS::HtmlRepresentation::ViewHelpers
end

class ActionController::Base
  include OJS::RenderRepresentation
  unless method_defined? :render_without_representation
    alias_method_chain :render, :representation
    prepend_before_filter do 
      OJS::HtmlRepresentation::Representation::reset_all
    end
    append_after_filter :fix_opera_xhr
    def fix_opera_xhr
      if request.env['HTTP_X_LIMITED_STATUS_CODE_SUPPORT']
        puts "STATUS #{response.headers['Status']}"
        response.headers['X-Intended-Status-Code'] = response.headers['Status']
        response.headers['Status'] = "200 OK"
      end
    end
  end
  
end
