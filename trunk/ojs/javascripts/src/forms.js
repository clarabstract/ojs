function showError(ev) {
  this.getElementsByClassName("errors")[0].insert(new Element("li",{className:"error"}).update(ev.memo.message))
}

var Validate = {}
Validate = {
  onSubmit: {
    "::submit":function(ev) {
      // ev.element().fire("form:validate")
      this.getElementsByClassName("errors")[0].update("")
      this.getElements().invoke('fire','form:validate')
      this.fire("form:validate")
    }
  },
  continuously: {
    //TODO
  }
}
Validation = {
  define: function(opts) {
    Validate[opts.name] = function(){
      var __rule_func = opts.rule, __rule_args = $A(arguments);
      validator = {
        rule: function(value) {
          return __rule_func.apply(this, [value].concat(__rule_args));
        },
        message: opts.message,
        with_message: function (new_message) {
          this.message = new_message;
          return this;
        }
      }
      validator["::form:validate"] = function(ev) {
        var el = ev.element()
        if(this.rule(el.getValue())) {
          // el.fire("form:validated")
        } else {
          el.fire("app:error",{message:this.message.gsub('#FIELD', el.name.capitalize())})          
        }
      }.bind(validator);
      return validator;
    }
  }
}
  

Validation.define({
  name:     'Pattern',
  message:  "#FIELD does not appear to be valid.",
  rule:     function(value, pattern) { 
              return pattern.test(value) 
            }
})

Validation.define({
  name:     'NotEmpty',
  message:  "#FIELD can't be empty.",
  rule:     Validate.Pattern(/[^\s]+/).rule
})

Validation.define({
  name:     'Email',
  message:  "#FIELD is not a valid email address.",
  rule:     Validate.Pattern(/^[-\w._%+]+@[\w.-]+\.[a-zA-Z]{2,6}$/).rule
})


