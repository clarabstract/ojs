if $0 == __FILE__
  require '../../language_extender.rb'
  require '../../language_extender/tree_writer_helper.rb'
  require '../../language_extender/translation'
  require '../../language_extender/language_definition'
  require '../../language_extender/scope'
  require 'language_definition'
end
module OJS
  module OjsLanguage
    class Translation < LanguageExtender::Translation
      def before_parse
        @instance_methods = []
        @class_methods = []
        @arguments_for = {}
        @body_for = {}
        @data[:classes] = []
        @data[:class_deps] = []
        @data[:file_deps] = []
      end
      def substitution_string(scope, parts)
        ['"',  parts[1...-1], '"']
      end
      def interpolated_source(scope, parts)
        ['"+(',  parts[1...-1], ')+"']
      end
      def string_content_string_part(scope, str)
        str.gsub('"','\"')
      end
      def instance_method_definition(scope, parts)
        @instance_methods << scope[:method_name]
        @last_method_def = scope[:method_name]
        parts
      end 
      def class_method_definition(scope, parts)\
        @class_methods << scope[:method_name]
        @last_method_def = scope[:method_name]
        parts
      end
      def method_body(scope, parts)
        @body_for[@last_method_def] = parts[1...-1]
        parts
      end
      def arguments(scope, parts)
        @arguments_for[@last_method_def] = scope.parts
        parts
      end
      def render_args(method_name)
        args = []
        @body_insertion = ""
        @arguments_for[method_name].each do |arg_scope|
          next unless arg_scope.respond_to? :name
          case arg_scope.name
          when :simple_argument
            args << arg_scope[:argument_name]
          when :argument_default
            args << arg_scope[:argument_name]
            @body_insertion << "#{arg_scope[:argument_name]} = typeof(#{arg_scope[:argument_name]}) != 'undefined' ? #{arg_scope[:argument_name]} : #{get_translation_for(arg_scope.children[0])};"
          when :array_argument
            @body_insertion << "#{arg_scope[:argument_name]} = Array.prototype.slice.call(arguments, #{args.size}, arguments.length);"
          end
        end
        args.join(", ")
      end
      def class_definition(scope, parts)
        parts = []
        super_class = scope[:super_class_name] || "Base"
        parts << "\nfunction #{scope[:class_name]}() {}\ndefine_class(#{scope[:class_name]},#{super_class},{"
        @data[:classes] << scope[:class_name]
        @data[:class_deps] << super_class
        @instance_methods.each_with_index do |meth_name,i|
          parts << "\n  #{meth_name}: function("
          parts << render_args(meth_name)
          parts << "){\n    "
          parts << @body_insertion
          parts << @body_for[meth_name].join
          parts << "\n  }"
          parts << "," unless i == (@instance_methods.size - 1)
        end
        parts << "\n},{"
        @class_methods.each_with_index do |meth_name,i|
           parts << "\n  #{meth_name}: function("
           parts << render_args(meth_name)
           parts << "){\n    "
           parts << @body_insertion
           parts << @body_for[meth_name].join
           parts << "\n  }"
           parts << "," unless i == (@class_methods.size - 1)
        end
      
        parts << "\n})"
        @instance_methods = []
        @class_methods = []
        parts
      end
      def default_super_call(scope, parts)
        [%{\n    arguments.callee.super_method && arguments.callee.super_method.apply(this,arguments);}]
      end
      def super_call_with_params(scope, parts)
        [%{\n    arguments.callee.super_method && arguments.callee.super_method.apply(this,[#{super_call_params}]);}]
      end
      def instance_member_accessor(scope, parts)
        [%{this.#{scope[:method_name]}}]
      end
      def class_member_accessor(scope, parts)
        [%{this.klass.#{scope[:method_name]}}]
      end
      def require_statement(scope, parts)
        @data[:file_deps] << scope[:require_file]
        [%{//require #{scope[:require_file]}}]
      end
      def foreach(scope, parts)
        own_idx = scope.parent.children.index(scope) #next scope (should be a block)
        scope.parent.children[own_idx + 1].parts.shift #remove first part (the opening bracket)
        ["var __things = ", parts[1..-1], ";for(var i = __things.length - 1; i >= 0; i--) {var #{scope[:current_item]} = __things[i];" ]
      end
      def unless(scope, parts)
        ["if(!(", parts[1...-1], "))"]
      end
    end
  end
end
if $0 == __FILE__
# puts OJS::Translation.new(%[var mydiv=#!<div id="\#{div_id + 1}" onclick="alert('\#{get_error(div_id)}')">Hello.</div>!;], OJS::Language).translate!(1)

source = <<-OJS
// My silly class
class Foo : Bar {
  @@after_defined(a=nil) {
    this.klass.prefix = "foo_";
  }
  @initialize(name) {
    this.name = name;
    super;
  }
  @@a_class_method(a,b,c=1,d=2,*spares) {
    do_this();
    and_that()
    and_the_other
  }
  @an_instance_method(a,b,*other) {
    whatevs;
  }
}
OJS

deps_and_reqs = <<-OJS
#require 'prototype.js'
#require 'base.js'
class Aaa : Xxx {
  @args_poo(a = #"a\#{sfa}", b=@good() ) {
    return "oh sht"
  }
  @good() {
    #foreach bee: @$(function(){return poo;}) {
      unless( bunny ) {
        beep.do() {oh:i,see}
      }//endunless
    }//endforeach
    one last thing for good()
  }//endgood
  @also_good() {
    
  }
}
class Bbb : Yyy {
  @umwhat() {
    
  }
}
class Cc : Zz {
  @boop() {
    
  }
}
OJS
puts translated_source = (t=OJS::OjsLanguage::Translation.new(deps_and_reqs, OJS::OjsLanguage::LanguageDefinition)).translate!(3)
pp t.data
end