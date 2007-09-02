module LanguageExtender
  class ScopeRule
    attr_accessor :scope_name, :child_rules, :start_pattern, :end_rule, :definition_caller, :consume_immediately, :language, :default, :unconditional_rule, :captures
    alias_method :consume_immediately?, :consume_immediately
    alias_method :default?, :default
    def initialize(language, scope_name)
      @language = language
      @scope_name = scope_name
      self.child_rules = []
    end
    def rules_defined?
      self.start_pattern
    end
    def can_have(child_scope_name, rules={})
      if rules[:for_pattern] && rules[:from]
        raise Language::LanguageDefinitionError, 
              "Scope rule :#{child_scope_name} inside :#{scope_name} has both :for_pattern and :from - pick one."
      end
      child_rule = @language.scope_rule(child_scope_name)
      if child_rule.rules_defined?
        unless rules.empty?
          raise  Language::LanguageDefinitionError, 
                "Rules for scope :#{child_scope_name} have already been defined. \nCreate an intermediate scope and specify that it can contain :#{child_scope_name} unconditionally"
        end
      end
      if (rules[:from] || rules[:for_pattern])
        child_rule.definition_caller = caller(1)
        child_rule.end_rule = rules[:to]
        child_rule.start_pattern = (rules[:from] || rules[:for_pattern])
        child_rule.consume_immediately = true if rules[:for_pattern]
        child_rule.start_pattern = Regexp.new(Regexp.escape(child_rule.start_pattern)) if child_rule.start_pattern.is_a? String
        child_rule.captures = rules[:capture].invert if rules[:capture]
        child_rules << child_rule
      else
        raise Language::LanguageDefinitionError, "Scopes can only have one condition-less rule. :#{self.scope_name} already has :#{self.unconditional_rule} so #{child_rule.scope_name} cannot be added." if self.unconditional_rule
        self.unconditional_rule = child_rule
      end
    end
    def end_pattern(captures)
      return nil unless end_rule
      rule_val = end_rule.dup
      if rule_val.is_a? String
        rule_val.gsub!(/(\\)?\\(\d)(?!:)?/) do |match|
          next $1+$2 if $1 == '\\'
          captures[$2.to_i]
        end
        rule_val.gsub!(/\\(\d):([\w_]+)/) do |match|
          @language.transforms[$2.to_sym].call(captures[$1.to_i-1])
        end
        rule_val.gsub!(/(\\:)/) do |match|
          ":"
        end
        rule_val = Regexp.new(Regexp.escape(rule_val))
      end
      rule_val
    end
    def to_tree_branch_str
      "  | #{@scope_name}  start:#{start_pattern.inspect} end:#{end_pattern(%w(FIRST_CAPTURE SECOND_CAPTURE THIRD_CAPTURE)).inspect} - #{@opts.inspect;nil}\n"
    end
  end
  class LanguageDefinition
    class LanguageDefinitionError < RuntimeError;end
    class << self
      attr_accessor :scope_rules, :current_definition_caller, :transforms
      def inherited(subclass)
        subclass.scope_rules = {}
        subclass.transforms = {}
      end
      def scope_rule(scope_name)
        scope_rules[scope_name] ||= ScopeRule.new(self,scope_name)
      end
      def inside(scope_name)
        self.first_rule = scope_rule(scope_name) if @starting_scope_name == scope_name
        scope_rule(scope_name)
      end
      def default_rule(scope_name = nil)
        return @default_rule if scope_name.nil?
        @default_rule = scope_rule(scope_name)
        @default_rule.default = true
        @default
      end
      def replacement_transform(name,&block)
        transforms[name] = block
      end
      def verify
        scope_rules.each_value do |s|
          s.child_rules.each do |c|
             # raise LanguageDefinitionError, "Scopes without end rules can't have children without end rules (Offending scopes :#{s.scope_name} and :#{c.scope_name})", c.definition_caller if c.end_rule.nil? && s.end_rule.nil?
          end
        end
      end
      def to_tree_str
        str = ""
        scope_rules.each_value do |s|
          str << "#{s.scope_name}:\n#{s.child_rules.collect(&:to_tree_branch_str).join}\n" unless s.child_rules.empty?
        end
        str
      end
    end
  end
end