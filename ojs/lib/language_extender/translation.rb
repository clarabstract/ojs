module LanguageExtender
  class Translation
    include LanguageExtender::TreeWriterHelper
    def initialize(source, language)
      @language = language
      @language.verify
      @source = source
      @data = {}
    end
    attr_accessor :data
    def translate!(explain = 0)
      self.explain_level = explain.is_a?(Fixnum) ? explain : {:explain=>1, :explain_in_detail=>2,:explain_in_excruciating_detail=>3}[explain] 
      if explain_level > 10
        nl "Using language definition #{@language.name}:\n"
        indent do
          nl @language.to_tree_str
        end
        nl "Source string:\n"
        line_num = 0
        offset = 0
        last_digit = nil
        if explain_level > 1
          @source.each do |line| 
            offset_range = (offset..(offset+line.size-1))
            out = "\n           " 
            out += offset_range.collect do |i| 
              current_digit = i.to_s.rjust(10,"0")[-2,1]
              if last_digit.nil? || last_digit != current_digit
                last_digit = current_digit
              else
                " "
              end
            end.join          
            out << "\n           " + offset_range.collect{|i| i.to_s[-1,1]}.join

            out << "\n  Line#{line_num.to_s.rjust(3)}: " + line
            offset += line.size
            line_num += 1
            out
            puts out
          end
        else
          indent do
            nl @source
          end
        end
        nl "\nBegin parse with :#{@language.default_rule.scope_name} :\n"
        self.prefix << "  "
      end
      before_parse
      scope = Scope.new(@language.default_rule, @source)
      nl "|__ ALL DONE :)\n\n===\n" if explain
      get_translation_for(scope)
    end
    def before_parse
    end
    def get_translation_for(scope)
      callback_for(scope, scope.parts.collect{|part| part.is_a?(Scope) ? get_translation_for(part) : string_part_callback_for(scope,part) } ).join
    end
    def string_part_callback_for(scope, str) 
      callback_name = "#{scope.name}_string_part".to_sym
      if respond_to? callback_name
        return send(callback_name, scope, str)
      else
        return send(:fallback_string_part_handler, scope, str)
      end
    end
    def callback_for(scope, parts)
      if respond_to? scope.name
        return send(scope.name, scope, parts)
      else
        return send(:fallback_handler, scope, parts)
      end
    end
    def fallback_string_part_handler(scope, str)
      str
    end
    def fallback_handler(scope, parts)
      parts
    end
  end
end