require File.join(File.dirname(__FILE__), *%w[.. lib ojs])
class TestTranslation < LanguageExtender::Translation
  def fallback_handler(scope)
    # puts scope.name.inspect
    # puts "  From:#{scope.start_token.inspect}"
    # puts "  To:#{scope.end_token.inspect}"
    # puts "  Parts:#{scope.parts.inspect}"
    # puts "  Children:#{scope.children.collect{|c|"#{c.name}:#{c.content}"}.inspect}"
    # puts "  Content:#{scope.content.inspect}"
    # 
    super(*scope)
  end
end
describe OJS::Language do
#   it "should description" do
#     test_string = <<OJS
#       var mystring = #"Hello my name is \#{ get_name(#"joe \#{ 2 * 3} " )}"
# OJS
#     test_string =  <<-OJS
#     /* multi-line
#     comment */
#     #"string_with_substituion! \#{foo + bar(34,23) - [:a,:b] + 'sq string' }bcd" zx (asf)
#     // single line comment
#     class Foo : Bar {
#       @poo ( an_arg , default_arg = [:poo], anotehr_arg, *rest) {
#         "hello"
#       }
#     }
#     OJS
#     puts "<pre>"
#      scp = TestTranslation.new(test_string, OJS::Language).translate!()
#     puts "</pre>"
#   end
end