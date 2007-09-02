require File.join(File.dirname(__FILE__), *%w[.. lib ojs])

describe OJS::Translation do
  it "should translate string interpolation" do
    translated = OJS::Translation.new(%q[var mydiv=#!<div id="#{div_id + 1}" onclick="alert('#{get_error(div_id)}')">Hello.</div>!;], OJS::Language).translate!
    translated.should eql(%q[var mydiv="<div id=\""+(div_id + 1)+"\" onclick=\"alert('"+(get_error(div_id))+"')\">Hello.</div>";])
  end
  it "should translate class definitions" do
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
    translation = OJS::Translation.new(source, OJS::Language)
    translated_source = translation.translate!
    expected = <<-JS
// My silly class

function Foo{}
define_class(Foo,Bar,{
  initialize: function(name){
    
    this.name = name    this.call_super("initialize", arguments);
  
  },
  an_instance_method: function(a, b){
    other = Array.prototype.slice.call(arguments, 2, arguments.length);
    whatevs;
  
  }
},{
  after_defined: function(a){
    a = typeof(a) != 'undefined' ? a : nil;
    this.klass.prefix = "foo_";
  
  },
  a_class_method: function(a, b, c, d){
    c = typeof(c) != 'undefined' ? c : 1;d = typeof(d) != 'undefined' ? d : 2;spares = Array.prototype.slice.call(arguments, 4, arguments.length);
    do_this();
    and_that()
    and_the_other
  
  }
})
JS
    expected.should eql(translated_source)
  end
  it "should determine reqs and classes for a file" do
    source = <<-OJS
    class A : X {
      @meep(){}
    }
    class B : Y {}
    class C : Z {}
    OJS
    translation = OJS::Translation.new(source, OJS::Language)
    translated_source = translation.translate!
    translation.data[:class_deps].should eql(%w(X Y Z))
    translation.data[:classes].should eql(%w(A B C))
  end
end