/**
The Dispatcher intercepts all all bubble-able events on the document. 
If the event's soruce element has an id that matches a certain pattern, the event is dispatched to a controller class
event callback.

An element that has a controller behind it must have an ID like:

  controller_name_23  ,or
  controller_name_N   for 'New' or 'Null' elements (i.e. singletons)
  controller_name_N3  

The reason for the later case is that the 'id' digit usually reflects a database ID. It's also a nice way to keep track
of js-generated 'unsaved' object along with saved ones.

Each such element will correspond to an instance of the controller object. 

Many elements can be 'related' to the same particular instance. Think of them as 'properties' or 'attributes' for the controller
object. Such elements have an ID like:
  
  controller_name_23_attribute_name

All events on 'controller_name_23' and 'controller_name_23_*' get dispatched to the controller instance, although attributes
are sent to different callback methods. 

The controller classes must be created using define_class() from class.js.

Initializing all controller instances on page load would create noticeable dealys, so instead they are instatiated on-demand 
(using .klass.i() ) when they actually need to recieve an event. All controllers get instantiated with a property .id set to
the element's 'id digit' (i.e. 23, N, or N23 etc)

The callback method will have a name like:
    
    on_<event name>                   e.g. on_click()
    on_<event name>_<attribute name>  for attribute elements, e.g. on_name_click() 

The callback arguments are:

  callback( element, event)         element being the source element, or
  callback( element, event, value)  for form field elements, where value is element.getValue()

Note that not all events bubble. Most notably, submit, change, focus, blur do not.

Currently Dispatcher will emulate focus/blur events, although it is not 100% accurate and this functionality might go away in
the future. 

The best way to handle these events is, unforunately, to simply use inline handlers that dispatch to a controller. The code is
mostly painless:

  <form  onsubmit="callback($(this).controller(), 'on_submit', [this, event]); return true;" ... >, or perhaps
  <input onchange="callback($(this).controller(), 'on_change', [this, event, $F(this)]); return true;" ... >

Additional callbacks:

on_any_event_for_<attribute name> and on_any_event() are fallback handlers you may choose to implement.

on_command() and on_action() are called for left-clicks elements of type 'A' (links) with an attribute command="command" or action="action",
in addition to their normal callbacks.

These are used by the OJS ElementController (which should be the base of all your contollers):
  Commands are links that simply perform some javascript (as opposed to real URLs). Their event is stopped by default.
  Actions are links to AJAX calls. Their href attribute is used for the request URL. Their event is stopped as well.

ElementController will also forward to an attribute handler, like on_<attribute name>_command().

Note that the above functionality is provided by ElementController, not Dispatcher. 

*/
var Dispatcher = {
  custom_event_handlers:[],
  handle: function(ev) {
    var el = Event.element ? Event.element(ev) : null;
    if(el.id) {
      var m = el.id.match(/^([a-zA-Z_]+)_(N\d+|N|\d+)(?:_([\w_]+)$)?/);
    }
    if(m){
      for (var i = Dispatcher.custom_event_handlers.length - 1; i >= 0; i--){
        Dispatcher.custom_event_handlers[i].event_filter(el, ev)
      };
      var controller_class = m[1], prop_name = m[3], inst_id = m[2];
      Dispatcher.dispatch(controller_class, prop_name, inst_id, ev)
    }
    return true
  },
  register_custom_event_handler: function(handler_obj) {
    Dispatcher.custom_event_handlers.push(handler_obj);
  },
  send_fake_event: function(event_name, source_element){
    Dispatcher.handle({target:source_element, type:event_name})
  },
  // TODO: Save memory by initing controllers that implement the proper callbacks.
  dispatch: function(controller_class_name, prop_name, inst_id, ev) {
    var el = Event.element(ev);
    var controller_klass = window[controller_class_name.camelize_underscores()]
    if(!controller_klass) return; 
    var controller = controller_klass.klass.i(inst_id);
    if(!controller) return;
    var el_value = el.getValue ? el.getValue() : null;
    if(ev.type == 'click' && el.tagName == 'A' && (ev.button == 0 || ev.which == 1) ) {
      if(el.getAttribute('remote_method') != null )  callback(controller, 'on_action', [el, ev, prop_name])
      if(el.getAttribute('command') != null )  callback(controller, 'on_command', [el, ev, prop_name])
    }
    var handler = controller["on_"+(prop_name == "" ? "" : prop_name + "_")+ev.type];
    if(handler) return handler(el, ev, el_value);
    var prop_handler = controller["on_any_event_for_"+prop_name];
    if(prop_handler) return prop_handler(el, ev, el_value);
    var fallback_handler = controller["on_any_event"];
    if(fallback_handler) return fallback_handler(el, ev, el_value);
  }
}

// var universalEvents = ["click","dblclick","mousedown","mouseup", "mouseup", "mouseover", "mousemove","mouseout", "keydown","keyup","keypress"] 
var universalEvents = ["click","dblclick","mousedown","mouseup", "mouseup", "keydown","keyup","keypress"] 
for (var i = universalEvents.length - 1; i >= 0; i--){
  Event.observe(document, universalEvents[i], Dispatcher.handle);
};

var FakeFocusBlur = {
  activeElement:null,
  event_filter: function(el, ev){
    // Focus/blur/submit simulation (they don't bubble)
    if(ev.type == "mousedown" || ev.type == "keyup") {
      var tag_name = el.tagName;
      // Events that can cause a focus/blur/submit
      if(FakeFocusBlur.activeElement != el) {
        // Something different then the active element was clicked/keyed - the focus must have changed
        FakeFocusBlur.fake_blur(FakeFocusBlur.activeElement);
        if(tag_name == "LABEL" || tag_name == "INPUT" || tag_name == "SELECT" || tag_name == "TEXTAREA" || tag_name == "BUTTON") {
          // Elements that can recieve focus events become focused
          FakeFocusBlur.fake_focus(el);
        }
      } else {
        if(ev.type == "keyup" && tag_name != "TEXTAREA" && ev.keyCode == Event.KEY_TAB) {
          // When the current element is active, and not a TEXTAREA, pressing TAB causes a blur
          Dispatcher.fake_blur(el);
        }
      }
    }
  },
  fake_focus: function(el){
    if(el) Dispatcher.send_fake_event("focus",el);
    FakeFocusBlur.activeElement = el;
  },
  fake_blur: function(el) {
    if(el) Dispatcher.send_fake_event("blur",el);
    FakeFocusBlur.activeElement = null;
  }
}

Dispatcher.register_custom_event_handler(FakeFocusBlur);

Event.observe(window, "blur", function(){
  FakeFocusBlur.fake_blur(FakeFocusBlur.activeElement);
});
  
