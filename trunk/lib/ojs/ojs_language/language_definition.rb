# require File.join(File.dirname(__FILE__), "language_extender", "language_extender")
module OJS
  module OjsLanguage
    class LanguageDefinition < LanguageExtender::LanguageDefinition
      default_rule :normal_source

      replacement_transform :get_pair do |capture|
        next ")" if capture == "("
        next "]" if capture == "["
        next "}" if capture == "{"
        next "<" if capture == ">"
        capture
      end
      
      inside(:normal_source).can_have                 :require_statement,           :for_pattern=>/\#require\s+\'([^\']+)\'/, 
                                                                                    :capture=>{1=>:require_file}

      inside(:normal_source).can_have                 :single_line_comment,         :from=>'//', 
                                                                                    :to=>"\n"

      inside(:normal_source).can_have                 :multi_line_comment,          :from=>'/*', 
                                                                                    :to=>'*/'
                                                                                    
                                                                                    
      inside(:normal_source).can_have                 :double_quote_string,         :from=>/"/, 
                                                                                    :to=>/"/

      inside(:normal_source).can_have                 :single_quote_string,         :from=>/'/, 
                                                                                    :to=>/'/
                                                                                        
      inside(:normal_source).can_have                 :substitution_string,         :from=>/\#([\[\(\{]|[^\w\s])/, 
                                                                                    :to=>'\1:get_pair'

      inside(:substitution_string).can_have           :string_content

      inside(:string_content).can_have                :meaningless_pairs_in_string, :from=>/([\(\[\{])/, 
                                                                                    :to=>'\1:get_pair'

      inside(:meaningless_pairs_in_string).can_have   :string_content

      inside(:string_content).can_have                :interpolated_source,         :from=>'#{',
                                                                                    :to=>'}'
                                                                                    
      inside(:interpolated_source).can_have           :normal_source
  
      inside(:normal_source).can_have                 :foreach,                     :from=> /#foreach\s+([$\w_]+)\s*:/, 
                                                                                    :to=>/(?=\{)/, 
                                                                                    :capture=>{1=>:current_item}
  
      inside(:foreach).can_have                       :normal_source
      
      inside(:normal_source).can_have                 :unless,                      :from=> /unless\s*\(/,
                                                                                    :to=>/\)/

      inside(:unless).can_have                        :normal_source
  
      inside(:normal_source).can_have                 :blocks_or_object_literals,   :from=>"{", 
                                                                                    :to=>"}"
      inside(:blocks_or_object_literals).can_have     :normal_source
      
      inside(:normal_source).can_have                 :grouping_brackets,           :from=>"(", 
                                                                                    :to=>")"

      inside(:grouping_brackets).can_have             :normal_source
  
      inside(:normal_source).can_have                 :array_literals,              :from=>"[", 
                                                                                    :to=>"]"
      
      inside(:array_literals).can_have                :normal_source

      inside(:normal_source).can_have                 :function_calls,              :from=>/[\w_]+\(/, 
                                                                                    :to=>")"

      inside(:function_calls).can_have                :normal_source

      inside(:normal_source).can_have                 :class_definition,            :from=>/(?:\A|;\s*|[\s\n]+)class\s+(\w+)\s*(?::\s*(\w+))?\s*\{/, 
                                                                                    :to=>"}", 
                                                                                    :capture=>{
                                                                                      1=>:class_name,
                                                                                      2=>:super_class_name
                                                                                    }

      inside(:class_definition).can_have              :instance_method_definition,  :for_pattern=>/@([$\w_]+)/, 
                                                                                    :capture=>{1=>:method_name}

      inside(:class_definition).can_have              :class_method_definition,     :for_pattern=>/@@([$\w_]+)/, 
                                                                                    :capture=>{1=>:method_name}

      inside(:class_definition).can_have              :single_line_doc_comment,     :from=>'//', 
                                                                                    :to=>"\n"

      inside(:class_definition).can_have              :multi_line_doc_comment,      :from=>'/*', 
                                                                                    :to=>'*/'

      inside(:class_definition).can_have              :arguments,                   :from=>"(", 
                                                                                    :to=>")"
    
      inside(:arguments).can_have                     :argument_separator,          :for_pattern=>","
  

      inside(:arguments).can_have                     :argument_default,            :from=>/([\w_]+)\s*\=/, 
                                                                                    :to=>/(?=,)|(?=\))/,
                                                                                    :capture=>{1=>:argument_name}

      inside(:argument_default).can_have              :normal_source

      inside(:arguments).can_have                     :array_argument,              :for_pattern=>/\*([\w_]+)\s*/, 
                                                                                    :capture=>{1=>:argument_name}

      inside(:arguments).can_have                     :simple_argument,             :for_pattern=>/([\w_]+)\s*/, 
                                                                                    :capture=>{1=>:argument_name}
  
      inside(:class_definition).can_have              :method_body,                 :from=>"{",
                                                                                    :to=>"}"
    
      inside(:method_body).can_have                   :normal_source
      
      inside(:normal_source).can_have                 :default_super_call,          :for_pattern=>/(?:\A|;\s*|[\s\n]+)super\s*(?:;|\n)/

      inside(:normal_source).can_have                 :super_call_with_params,      :for_pattern=>/(?:\A|;\s*|[\s\n]+)super\s*\((.*)\)(?:;|\n)/, 
                                                                                    :capture=>{1=>:super_call_params}
      
      inside(:normal_source).can_have                 :instance_member_accessor,    :for_pattern=>/@([$\w_]+)/, 
                                                                                    :capture=>{1=>:method_name}

      inside(:normal_source).can_have                 :class_member_accessor,       :for_pattern=>/@@([$\w_]+)/, 
                                                                                    :capture=>{1=>:method_name}
      
    end
  end
end