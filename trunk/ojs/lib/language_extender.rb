require 'strscan'

module LanguageExtender
  def dbg(str)
    outstr = "dbg#{caller[0][/:\d+/]}"
    if str =~ /\n/
      outstr << ">>\n#{str.collect{|l|"  " + l}}\n/dbg"
    else
      outstr << ":#{str}"
    end
    puts outstr
  end
  
end


class Symbol
  unless method_defined? :to_proc
    def to_proc
      Proc.new { |obj, *args| obj.send(self, *args) }
    end
  end
end

