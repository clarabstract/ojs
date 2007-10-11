module LanguageExtender
  class Scope
    include LanguageExtender::TreeWriterHelper
    attr_accessor :limit
    attr_reader :name, :source, :offset, :parent, :rule, :end_part, :parts, :children, :end_part_offset, :start_part, :start_captures
    def initialize(rule, source, parent=nil, start_part=nil, start_captures=nil)
      @rule = rule
      @source = source
      @name = rule.scope_name
      @parent = parent
      @start_part = start_part
      @start_captures = start_captures
      @offset = 0
      @start_token_limit = parent.end_part_offset if parent
      @parts = start_part ? [start_part] : []
      @children = []
      @@ids ||= 0
      @small_id = (@@ids += 1)
      parse
    end
    def [] (named_capture)
      @start_captures[@rule.captures[named_capture]-1]
    end
    def content
      parts.collect{|part| part.is_a?(Scope) ? part.content : part }.join
    end
    def inner_content
      inner_parts.collect{|part| part.is_a?(Scope) ? part.content : part }.join
    end
    def parse
      content = ""
      nl "|--:#{id_name}" 
      while next_scope = self.next_part do
        raise "Unterminated scope #{id_name} around:\n #{search_space}" unless next_scope.end_part_offset
        advance_by(next_scope.end_part_offset)
        @children << next_scope
      end
      nl "#{algn"|__#{id_name}: completed", "_"}[ #{parts.collect{|p| p.is_a?(Scope) ? p.id_name : p.inspect}.join(", ")} ]", 1
      # nl "|__completed #{id_name}: #{parts.collect{|p| p.is_a?(Scope) ? p.id_name.to_sym : p}.inspect}"

    end
    def inner_parts
      parts[1...-1]
    end
    def start_token_limit
      @start_token_limit ? @offset + @start_token_limit : nil
    end
    def advance_by(amount)
      nl "|..advancing #{id_name} by #{amount} -- #{caller[0][/\d+/]}",3
      @offset += amount
    end
    def first_parent_end_pattern
      p = self.parent
      until p.rule.end_rule
        p = p.parent
      end
      p.rule.end_pattern(p.start_captures)
    end
    # Looks ahead of offset for either a new scope (in which case the new scope is returned)
    # or the end of the current scope (in which case nil is returned).
    def next_part
      nl "#{algn"|::#{id_name}: search_space"}#{search_space.inspect}", 3
      nl "#{algn"|::#{id_name}: limit"}#{" "*(start_token_search_space.inspect.size-2)}^", 3
      nl "#{algn"|::#{id_name}: find own end pattern"}#{@rule.end_pattern(start_captures).inspect}", 3
      
      # If this happens to be a for_pattern rule (which by definition, can't have children)
      if @rule.consume_immediately?
        nl "|::#{id_name}: CONSUME SELF IMMEDIATELY", 3 
        # Set the end part to "" and stop looking for parts
        @end_part = nil
        @end_part_offset = 0
        return nil
      end

      # By default, always look for our own end pattern
      end_patterns = {:own_end_pattern => proc{ @rule.end_pattern(start_captures) }}
      
      # If we have no end rule, look for the parent's rule instead
      if @rule.end_rule.nil? && parent
        nl "#{algn"|::#{id_name}: or parent end pattern"}#{first_parent_end_pattern.inspect}", 3
        end_patterns[:parent_end_pattern] = proc {
          first_parent_end_pattern
        }
      end
      first_match = Match.first(search_space, @rule.child_rules, start_token_limit, 
        #Look for any of our possible child rules' start patterns
        proc{|obj|
          obj.start_pattern
        },
        #... if matched by their end patterns
        proc{|obj, captures|
          obj.end_pattern(captures)
        #Or one of the end patterns we are looking for - whichever comes sooner  
        }, end_patterns)

      #If we have an unconditional_rule, and we found no start rules
      if @rule.unconditional_rule  && (!first_match || !first_match.matched_obj)
        nl "|:::#{id_name}: UNCONDITIONAL RULE  #{@rule.unconditional_rule.scope_name.inspect}  ", 3 
        unless @used_up_unconditional
          # Fake a match for the unconditional rule (matching the whole search_space end to end)
          new_scope = nil
          indent "|  " do
            new_scope = Scope.new(@rule.unconditional_rule, search_space, self)
          end
          @parts << new_scope
          @used_up_unconditional = true
          return new_scope
        else
          nl "::: but it was used up",3
        end
      end
      
      # Nothing else is left - we probably ran out of source
      if first_match.nil?#  && parent.nil?
        @parts << search_space
        nl "|:::#{id_name}: FOUND NOTHING AT ALL .. #{search_space.size} chars added to parts", 1
        return nil
      end
      
      # if we matched one of our children's start rules, create a new scope for them
      if first_match.matched_obj
        nl "|:::#{id_name}: FOUND NEW SCOPE START  #{first_match.matched_obj.scope_name.inspect}", 3
        @parts << first_match.find_match.pre_match
        advance_by(first_match.find_match.end(0))
        new_scope = nil
        indent "|  " do
          new_scope_start_part = first_match.find_match[0]
          new_scope_start_captures = first_match.find_match.captures
          new_scope = Scope.new(first_match.matched_obj, first_match.full_post_find_match, self, new_scope_start_part, new_scope_start_captures)
        end
        @parts << new_scope
        return new_scope
      end
      
      # If you found an end_pattern, take note of where you found it and return yourself
      if which_end = first_match.matched_additional
        src_to_end_part = first_match.find_match.pre_match
        @parts << src_to_end_part unless src_to_end_part.empty?
        @end_part_offset = @offset
        if which_end == :own_end_pattern
          @end_part_offset += first_match.find_match.end(0)
          @end_part = first_match.find_match[0]
        elsif which_end == :parent_end_pattern
          # When matching an unconditional end (via it's parent) we want to return BEFORE the actual end token (so the parent may properly consume it)
          @end_part_offset += first_match.find_match.begin(0)
          @end_part = ""
        end
        @end_part = nil if @end_part.empty?
        @parts << @end_part unless @end_part.nil?
        nl "|:::#{id_name}: FOUND END TOKEN  #{first_match.matched_additional.inspect} at offset #{@end_part_offset}", 3
        return nil
      end
    end

    def search_space
      @source[@offset..-1]
    end
    def start_token_search_space
      limit ? search_space[0..start_token_limit] : search_space 
    end
    def id_name
      "#{@name}(##{@small_id})"
    end
    def total_offsets
      offsets = @offset
      s = self
      while s = s.parent
        offsets + s.offset
      end
      offsets
    end
    def all_parents
      parents = []
      s = self
      while s = s.parent
        parents << s.id_name
      end
      parents
    end
  end
  class Match
    attr_accessor :find_match, :verify_match, :matched_obj, :source_string, :matched_additional
    def full_post_find_match
      source_string[find_match.end(0)..-1]
    end
    class << self
      def first(string, objects, find_limit, find_block, verify_block, additional_finds)
        return nil unless string
        find_str = find_limit ? string[0..find_limit] : string
        first_match = nil
        update_first_match = lambda { |current_match|
          if first_match.nil? || current_match.find_match.begin(0) < first_match.find_match.begin(0)
            first_match = current_match
          end
        }
        additional_finds.each do |find_name,additional_find|
          current_match = self.new
          current_match.source_string = string
          pattern = additional_find.call || next
          current_match.find_match  = pattern.match(find_str) || next
          current_match.matched_additional = find_name
          update_first_match.call(current_match)
        end
        objects.each do |obj|
          current_match = self.new
          current_match.source_string = string          
          current_match.find_match = find_block.call(obj).match(find_str) || next
          if verify_block
            pattern = (verify_block.call(obj, current_match.find_match.captures) || /\Z/)
            current_match.verify_match = pattern.match(current_match.find_match.post_match) || next
          end
          current_match.matched_obj = obj
          update_first_match.call(current_match)
        end
        first_match
      end
    end
  end
end