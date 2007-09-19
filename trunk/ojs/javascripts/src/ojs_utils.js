Object.extend(String.prototype, {
  camelize_underscores: function() {
    var parts = this.split('_'), len = parts.length, camelize_underscores="";
    for (var i = 0; i < len; i++)
      camelize_underscores += parts[i].capitalize();
    return camelize_underscores;
  },
  strip_nonwords: function() {
    return this.gsub(/^[^\w]+|[^\w]+$/,'')
  },
  to_ojs_parts: function() {
    var m = this.match(/^([a-zA-Z_]+)_(N\d+|N|\d+)(?:_([\w_]+)$)?/);
    if(m) return {controller_class:m[1], instance_id: m[2], attribute_name: m[3]}
  }
});

Element.addMethods({
  controller: function(element) {
    var el_parts;
    if(!element.id || !(el_parts = element.id.to_ojs_parts()) ) return null;
    var controller_klass = window[el_parts.controller_class.camelize_underscores()];
    if(controller_klass)  return controller_klass.klass.i(el_parts.instance_id);
    return null;
  },
  handle: function(element, event) {
    var controller;
    if(controller = element.controller()) controller.handle(element, event) 
    return true;
  },
  visibility: function(element, value) {
    element.setStyle({visibility: (value ? "visible" : "hidden")});
    return element;
  },

  restoreStyles: function(element) {
    return element.setStyle(element._originalStyles)
  },
  // Either an array or an object hash.
  saveStyles: function(element, styles) {
    var save_only_styles = [];
    var set_styles = { };
    if(Object.isArray(styles)) {
      save_only_styles = styles;
    } else {
      if(Object.isString(styles)) {
        save_only_styles = $A(arguments).slice(1);
      }else{
        set_styles = styles;
        save_only_styles = $A(arguments).slice(2);
      }
    } 
    element._originalStyles = {}

    for (var i = save_only_styles.length - 1; i >= 0; i--){
      var s = save_only_styles[i];
      element._originalStyles[s] = element.getStyle(s)
    };

    for(p in set_styles) {
      element._originalStyles[p] = element.getStyle(p)
    }
    element.setStyle(set_styles)
    
    return element;
  }
})

function _dispatch_event(ev) {
  if(ev.element) ev.element().handle(ev)
}
var dispatchable_events = ["click","dblclick","mousedown","mouseup", "mouseup", "keydown","keyup","keypress"] 
for (var i = dispatchable_events.length - 1; i >= 0; i--){
  Event.observe(document, dispatchable_events[i], _dispatch_event);
};


// Creates an anonymous function that calls +func+ and then returns the negated output.
function negate(func) {
  return function() {
    return !(func.apply(this, arguments))
  }
}

// Runs method on obj with args if obj.method exists
function callback(obj, method, args) {
  args = args || [];
  if(obj && obj[method]) return obj[method].apply(obj, args)
}

//Template transform - allows values to default to null
function _t(obj, m) {
  if(obj && obj[m]) return obj[m];
  if(m=='id') return 'N'
  return ''
}

//Hacky fix for Opera's improper handling of responseText with non-200 status codes
// Requires server to cooperate
if(window.opera) {
  Ajax.Responders.register({
    onCreate: function(req) {
      req.options.requestHeaders = req.options.requestHeaders || {}
      req.options.requestHeaders['X-Limited-Status-Code-Support'] = true;
      req.options.__original_on200 = req.options.on200;
      req.options.__original_onComplete = req.options.onComplete;
      req.options.onComplete = function() {
        req.options.onComplete = req.options.__original_onComplete;
        req.respondToReadyState(4);
      }
      req.options.on200 = function(resp){ 
        var real_status;
        if(real_status = resp.getResponseHeader('X-Intended-Status-Code')) {
          var s_match = real_status.match(/^\s*(\d+)\s+(.+)/);
          req.transport = Object.clone(resp)
          req.transport.status = Number(s_match[1])
          req.transport.statusText = s_match[2]
          req.transport.getResponseHeader = function(header){return resp.getResponseHeader(header)}
        }
        req.options.on200 = req.options.__original_on200;
      }
    }
  });
}


/** 
Models an point in the DOM tree, consisting of an element and a direction (either top, bottom, before, or after).


direction - Required. Can be simply a direction (one of top, bottom, before, or after),
    or a string of the form "<direction>:<elementID>". If the latter, the element argument
    is not required.
element - Optional. The element relative to which the direction applies. Not required if the
    second format above is used for the direction argument.

*/
function InsertionTarget (direction, element) {
  // If element is not defined, we assume direction is a string of
  // the form (top|bottom|before|after):element_id, and parse it.
  if (!element)
  {
    var re = /^(top|bottom|before|after):([\w-]+)$/i
    var match;
    if (match = re.exec(direction))
    {
      this.direction = match[1].capitalize()
      this.element = $(match[2])
    } else {
      return; //Something went wrong - probably couldn't find the element id.
    }
  } else {
    this.direction = direction.capitalize(); 
    this.element = element;
  }
}
// Inserts the some HTML at the insertion target using Prototype's insertion methods.
// html - Required. The HTML to insert.
InsertionTarget.prototype.insert = function(html){
  return new window.Insertion[this.direction](this.element, html);
}


Element.addMethods({
  bottom: function(element) {
    return new InsertionTarget('Bottom',element);
  },
  top: function(element) {
    return new InsertionTarget('Top',element);
  },
  after: function(element) {
    return new InsertionTarget('After',element);
  },
  before: function(element) {
    return new InsertionTarget('Before',element);
  }
});