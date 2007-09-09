module LanguageExtender
  module TreeWriterHelper
    def self.included(other_mod)
      @@prefix =  ""
    end
    def nl(str=" ", level=1)
      $stdout << "\n#{str.collect{|line|(prefix+line)[0,220]}.join}" if explain_level >= level
    end
    def algn(str, with=".")
      str.ljust(40, with) + with*(50 - @@prefix.size) rescue "TREE OUT OF RANGE"
    end
    def explain_level; @@explain_level || 0; end
    def explain_level=(val); @@explain_level=val; end
    def prefix; @@prefix; end
    def prefix=(val); @@prefix; end
    def a(str)
      $stdout << str
    end
    def indent(with="  ")
      @@prefix << with
      yield
      @@prefix.slice!(-with.size, with.size)
    end
  end
end
