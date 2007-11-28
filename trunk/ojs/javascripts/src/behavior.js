/*
Behavior-style extentions to prototype.
  by Ruy Asan

Highlights:
  - Observes events by css-selector
  - Remembers all active selectors and can re-apply them to new/modified elements
  - Can use efficient event delegation (and does so by default for all elements that can bubble)
  - Allows trigger delegation with inline event handlers for events that don't bubble
  - Uniform interface to stop onserving a given selector (applied using either method), can be further limited 
    by event type and handler, or can simply stop observing ALL events registered through it
  - Can assign either individual handler functions or behavior modules (which keep their own handler functions)
  
Problems:
  Allow behaviors to attach another (pre-req) behavior.
    > Resolved by ::behavior:added callback/event.
  Certian behaviors (like custom events) should only attach once.
    --- to be resolved via named attachment
  Allow behaviors to configure an element the first time (and only the first time) they are ran.
    --- to be resolved via ::behavior:attached callback

  - All behaviors need to have a name - user supplied name or auto-generated.
    Only 1 behavior of that name can be applied to an element. (makes it easy to not call ::behavior:attached twice)
    
    e.g.
      Tokenize() -> name = "tokenize"
      ".foo": Tokenize(spaceTokenizerFn) 
      ".bar": Tokenize(csvTokenizerFn) 
      
      <.foo.bar>.behaviors.tokenize.tokenizerFn == spaceTokenizerFn (since it was last)
       should throw a warning ?
      <.foo>.behaviors.tokenize.tokenizerFn == spaceTokenizerFn
      <.bar>.behaviors.tokenize.tokenizerFn == csvTokenizerFn
      

Design Decision Notes:
  - Ordering behaviors IS your responsibility.


Event Selectors:
  A string describing a particular event.

  <event name> (<event parameters>)* !<attachment method>*
  * = optional
  <event name>          is the DOM event name (e.g. "click") or a cusotm event name ("dom:loaded").
  <event parameters>    allow you to filter within a particular event. e.g. "keypress(ENTER +ctrl)". See also: EventFilters module.
  <attachment method>  forced observer attachment to be done either directly or via delegation.
                        e.g.  "click !direct"
                              "focus !delegated"
                              
Behavior Modules:
  Behavior modules are simply objects that have properties in the form of "::<event selector>" (see above).
  
  e.g. {
        "::click":function(event){
            alert("Hello there!");
         }
       }
  
  They are usually passed to the Behavior() function. There is nothing terribly special about them. You can use an instantiated
  class, a consturctor function ("return {...}") or anything else really. 
  
  Note:
    - Your handler functions (those that begin with "::") will receieve the event object as their first argument.
    - *Important!* Unlike normal event handler functions, this will NOT refer to the event's source element. Event handler functions
      will be bound (using .bind) to their parent object. (The element can still be accessed using ev.element)
    - Functions that don't begin with "::" are simply ignored.
  
  Fake events:

    ::behavior:applied
    
      Called as soon as your behavior is applied, allowing you to add prerequisite behaviors if needed.
      
      ev.selector
    
    "::element:configure"
      
      Called whenever we first encounter an actual instance of the element you are observing. In the case of directly observed events, 
      this will happen as soon as you add the behavior in question. In the case of delegated events, it will happen as soon as the element
      is matched by a document-wide listener.
      
      ev.element()
        
    
  
*/

Behavior = Class.create({
  initialize: function(options) {
    this.options = options;
  },
  wireToEvents: function() {
    var eventNames = $A(arguments);
    var handlerName = eventNames.shift();
    var handler = this.permaBind(handlerName);
    for (var i = eventNames.length - 1; i >= 0; i--){
      var eventName = eventNames[i];
      var existingHandler = this["::"+eventName];
      if(existingHandler) {
        if(!Object.isArray(existingHandler)) this["::"+eventName] = [existingHandler]
        this["::"+eventName].push(handler)
      } else {
        this["::"+eventName] = handler 
      }
    };
  },
  permaBind: function(methodName) {
    if(!this[methodName].behavior) {
      this[methodName] = this[methodName].bind(this).methodize()
      this[methodName].behavior = this
    }
    return this[methodName];
  }
})


// The event caches
EventCache = {}
DelegatesBySelectorCache = {}
EventFilters = {}
AttachmentCache = {}

Behavior._identifierCounter = 0
Behavior.create = function(name_or_methods, methods) {
  var args = $A(arguments).reverse();
  var behaviorClass = Class.create(Behavior, args[0]);
  behaviorClass.classIdentifier = args[1] || ++Behavior._identifierCounter;
  return behaviorClass;
}


/*  Behavior.add()

      Attach behavior to some elements (based on selector).

    Several call signatures:
    
    Simple event to function hookup
      Just a shortcut for Event.observeElements(selector, eventSelector, handler). 
      See also: Event Selectors

      e.g. Behavior.add(".css.selector::event(selector)", someFunction )
    
    Attactch a whole set of handlers  :
      Provide an object whose properties can be mapped to event handlers.
      See also: Behavior Modules

      e.g. Behavior.add(".css.selector", {"::event(selector)":handlerFunction, "::another:selector":anotherHandler, etc})
    
    Multiple handlers.
      Provide an array of functions or modules to attach them all at the same time.
      
      e.g. Behavior.add(".css.selector", [firstModule, secondModule, thirdModule] )
           Behavior.add(".css.selector::event(selector)", [firstFunction, secondFunction, thridFunction] )
    
    Multiple selectors
      As a convenience, if you provide a hash (as in, map/dictionary/JS Object) as the first argument, each member
      will be applied as a selector/handler pair.

      e.g. Behavior.add({
             ".selector":    aModule
             ".blah::click": [aFunction, anotherFunction]
           })
      
      Is the same as:
           Behavior.add(".selector", aModule)
           Behavior.add(".blah::click", [aFunction, anotherFunction])
    
*/

Behavior.add = function(selector, handler) {
  if(Object.isString(selector)) {
    if(Object.isArray(handler)) {
      //Applying several handlers for a selector
      for (var i=0; i < handler.length; i++) {
        Behavior.add(selector, handler[i])
      };
      return;
    }
    if(r = selector.match(/^(.*?)::(.*)$/)){
      //Applying a handler function directly
      Event.observeElements(r[1], r[2], handler)
    } else {
      //Applying a behavior module.
      Behavior.addModule(selector, handler)
    }   
  } else {
    //Configuring many selectors at once
    for( s in selector) {
      Behavior.add(s, selector[s])
    }
  }
}

/*  Actual implementation for Behavior.add with modules.
    (Treat as private)
    
    In addition to hooking-up "::*" methods as observers, it also:
      - addedToSelector callback
      - attachedToElement callback
    
    NOTE: maybe this functionality would live a happier life in Behavior.create et al?
*/
Behavior.addModule = function(selector, module) {
  if(module.addedToSelector)  module.addedToSelector(selector) ;
  for(m in module) {
    var r;
    if( r = m.match(/^::(.*)/) ) {      
      Event.observeElements(selector, r[1], module[m]) 
    }
  }
}








// Behavior specific functions later mixed into Event
EventExtentions = {
  // Allows consistent access to the event name via ev.name (i.e. also works for custom events)
  extend: Event.extend.wrap(
    function(proceed, event) {
      event.name = event.name || event.eventName || event.type;
      return proceed.apply(this, Array.prototype.slice.call(arguments,1))
    }
  ),
  // Works like Event.Observe but accepts selectors instead of a single element or id
  // Also allows re-application of events after a page update.
  // (Note: usually Event.observeElements should be used instead - use this only to force direct observing even if delegation is possible)
  observeElementsDirectly: function(sel, eventName, handler) {
    EventCache[sel] = EventCache[sel] || {}
    EventCache[sel][eventName] = EventCache[sel][eventName] || []
    EventCache[sel][eventName].push(handler)
    $$(sel).each(Event._observeElementDirect.rightCurry(1, eventName, handler, sel))
  },
  // Call this to re-apply any event observing selectors for a new element.
  // ***ONLY NEEDED IF YOU'RE NOT USING DELEGATED EVENTS***
  // ... don't recommend using it too often.
  updateObserversFor: function(newElement) {
    newElement = $(newElement)
    for(sel in EventCache) {
      var matchingElements = newElement.getElementsBySelector(sel)
      for (var i=0; i < matchingElements.length; i++) {
        for(eventName in EventCache[sel]) {
          var handlers = EventCache[sel][eventName]
          for (var j=0; j < handlers.length; j++) {
            Event._observeElementDirect(matchingElements[i],eventName, handlers[j], sel)
          };
        }
      };
    }
  },
  // PRIVATE - allows us to perform additional work before Event.observe()
  _observeElementDirect: function(element, eventName, handler, selector){
    if(Event._checkDuplicateClassIdentifier(element, handler)) {
      Event.observe(element, eventName, handler);
    }
  },
  // PRIVATE - ensures element doesn't have handlers from behaviors with same class identifiers
  // (also calls the attachedToElement callback if apropriate)
  _checkDuplicateClassIdentifier: function(element, handler) {
    var attachmentCallback;
    try {
      var clId = handler.behavior.constructor.classIdentifier;
      window.behaviors = window.behaviors || []
      if(!element.attachedBehaviors) element.attachedBehaviors = {};
      if(element.attachedBehaviors[clId]) {
        if(element.attachedBehaviors[clId] != handler.behavior) return false;
      } else {
        element.attachedBehaviors[clId] = handler.behavior
        attachmentCallback = handler.behavior.attachedToElement
      }
    } catch (e) { return true; }
    if(attachmentCallback) attachmentCallback(element);
    return true; 
  },
  // Like observeElementsDirectly, allows for use of selectors (to match several elements at once)
  // Unlike it, it uses the eficient and durable method of event delegation
  //    i.e. there is no need to walk the DOM tree to find the elements matching the selector first
  //    This also means that it will work just fine on elements that don't yet exist on the page
  // (Note: usually Event.observeElements should be used instead - it is smart enough to know that certain,
  // events don't bubble and will directly observe those instead. However, you can force delegation using this 
  // method if, for instance, you're using inline handlers with Event.delegate(event) for performance reasons)
  observeElementsWithDelegation: function(sel, eventName, handler) {
    var delegateHandlerName = Event._makeDelegateHandler(eventName)
    Event[delegateHandlerName].handlers[sel] = Event[delegateHandlerName].handlers[sel]  || []
    Event[delegateHandlerName].handlers[sel].push(handler)
    // Save in a more convenient hash for stopObservingSelector
    DelegatesBySelectorCache[sel] = DelegatesBySelectorCache[sel] || {}
    DelegatesBySelectorCache[sel][eventName] = Event[delegateHandlerName].handlers[sel]
    
    //Don't observe for events that (theoretically) never bubble
    if(!Event._neverBubbles[eventName]) Event.observe(document, eventName, Event[delegateHandlerName] )
  },
  // For performance reason it is a hash rather then an array
  // You can modify Event.doesNotBubble if you wish to always use inline delegation for these events
  doesNotBubble: {
    // Populated from Event._neverBubbles
  },
  // PRIVATE - these events will never be observed for the document - even when forced to. Only modify if you know
  // for a fact the browser will actually honest-to-god bubble these events
  _neverBubbles: {
    focus: true, blur: true, submit: true, change: true
  },
  // Allows one to observe events based on CSS-Selectors.
  // It will use observeElementsWithDelegation unle"ss the eventName is in the doesNotBubble list, in which case it will use observeElementsDirectly
  // This behavior can be over-ridden by appending "-direct" or "-delegated" to the eventName
  //    e.g. observeElements(".foo", "click-direct", func) or observeElements(".foo", "submit-delegated", func)
  // TODO: document filters
  observeElements: function(sel, eventString, handler) {
    var r = eventString.match(/(.*?)(\((.*?)\))?(-(direct|delegated))?$/)
    var eventName = r[1]; var filterParam = r[3]; var forceMethod = r[5];
    
    var observeMethod = Event.doesNotBubble[eventName] ? Event.observeElementsDirectly : Event.observeElementsWithDelegation
    if(forceMethod == "direct") observeMethod = Event.observeElementsDirectly
    if(forceMethod == "delegated") observeMethod = Event.observeElementsWithDelegation

    // console.log("Observe", sel, "::"+eventName, observeMethod == Event.observeElementsDirectly ? "direct" : "delegated", filterParam ? (" with filter (" + filterParam) + ")" : "",   EventFilters[eventName] )
    if(filterParam && (filterFunctions = EventFilters[eventName]) ) {
      observeMethod(sel, eventName, Event._filterHandler(filterFunctions, filterParam, handler) )
    } else {
      observeMethod(sel, eventName, handler)
    }
  },
  // Stops observing a particular selector, possibly for just a particular eventName, possibly for just a particular handler
  // Will stop observing current AND future elements for that selector
  // Performance warnings: 
  //      - runs $$() if you have direct observers
  //      - has to do a breadth-first transversal search pretty much no matter what
  stopObservingSelector: function(selector, eventName, handler) {
    if(eventName) {
      try{
        if(handler) DelegatesBySelectorCache[selector][eventName].remove(handler);
        else        DelegatesBySelectorCache[selector][eventName].clear();
      } catch(e){}
      if(EventCache[selector] && EventCache[selector][eventName] ) {
        if(handler) EventCache[selector][eventName].remove(handler);
        else        delete EventCache[selector][eventName];
        $$(selector).invoke('stopObserving', eventName, handler)
      }

    } else {
      if(EventCache[selector]) {
        delete EventCache[selector]
        $$(selector).invoke('stopObserving')
      }
      for(evN in DelegatesBySelectorCache[selector]) {
        DelegatesBySelectorCache[selector][evN].clear();
      }
    }
  },
  // Removes all existing or selector-based observers, for all current or future elements.
  // Good way to do a clean house completely and start form a blank state
  stopObservingAllSelectors: function() {
    for(sel in EventCache) {
      $$(sel).invoke('stopObserving')
    }
    EventCache = {}
    for(dhName in Event) {
      if(r = dhName.match(/^__handler_for_(.*)/)) {
        var eventName = r[1]
        Event.stopObserving(document, eventName, Event[dhName])
        delete Event[dhName]
      }
      DelegatesBySelectorCache = {}
    }
  },
  delegate: function(ev) {
    ev = Event.extend(ev)
    Event[Event._makeDelegateHandler(ev.name)](ev)
  },
  addFilter: function(eventName, filterFn) {
    EventFilters[eventName] = EventFilters[eventName] || []
    EventFilters[eventName].push(filterFn)
  },
  // PRIVATE - a factory for creating a delegate handler for a particular event type
  _makeDelegateHandler: function(eventName) {
    var delegateHandlerName = "__handler_for_"+eventName
    if(!Event[delegateHandlerName]) {
      Event[delegateHandlerName] = function(ev) {
        var handlers = Event[delegateHandlerName].handlers
        var element = ev.element()
        for(sel in handlers) {
          if(element.match && element.match(sel)) {
            var selHandlers = handlers[sel];
            for (var i=0; i < selHandlers.length; i++) {
              if(  Event._checkDuplicateClassIdentifier(element, selHandlers[i]) 
                   && !ev.stopped
              ) {
                selHandlers[i].call(element, ev)
              }
            }
          }
        }
      }
      Event[delegateHandlerName].handlers = {}
    }
    return delegateHandlerName
  },
  // PRIVATE - factory for filtered event handlers
  _filterHandler: function(filterFunctions, filterParam, handlerFn) {
    return function(ev) {
      for (var i=0; i < filterFunctions.length; i++) {
        var filterFn = filterFunctions[i];
        if((ev.stopped) || !filterFn(filterParam, ev)) return false;
      }
      handlerFn.call(this, ev)
    }
  }
}
Object.extend(Event, EventExtentions)
Object.extend(Event.doesNotBubble, Event._neverBubbles)


Filters = {
  /*  Mouse button filter.

      Applied to: click, mouseup, mousedown
      
      Params:
        ::click(left)    - only left (normal) clicks
        ::click(right)   - only right clicks
        ::click(middle)  - only middle clicks
  */
  mouseBtnFilter: function(filterParam, ev) {
    var filterParam = filterParam.match(/^[-\w\d_]+/)[0].toLowerCase()
    switch(filterParam) {
      case "left":    return Event.isLeftClick(ev);   break;
      case "right":   return Event.isRightClick(ev);  break;
      case "middle":   return Event.isMiddleClick(ev); break;
    }
  },
  /*  Key filter
      
      Applied to: keyup, keydown, keypress (not reliable)
      
      Params:
        ::keyup(RETURN)   - Any key from Event.KEY_*
        ::keyup(a)        - Match to specific char
        ::keyup(A)        - also matches (it's case insensitive - use +shift if you don't want that)
  
  */
  keyFilter: function(filterParam, ev) {
    var filterParam = filterParam.match(/^[-\w\d_]+/)[0].toUpperCase()
    if( ev.keyCode == Event["KEY_"+filterParam]) return true;
    if(String.fromCharCode(ev.charCode || ev.keyCode).toUpperCase() == filterParam) return true;
  },
  /*  Modifier key filter
      
      Applied to: mouseup, mousedown, click, keyup, keydown, keypress
      
      Params:
        ::click(+shift)   
        ::click(+alt)  
        ::click(+ctrl)  
        ::click(+meta)  
  */
  modifierKeyFilter: function(filterParam, ev) {
    var r = filterParam.match(/(\+|\-)(shift|alt|ctrl|meta)/i);
    if(!r) return true;
    var inclusion = r[1];var modifier = r[2].toLowerCase(); 
    return !!(inclusion == "+") == !!(ev[modifier+"Key"]);
  }
}
Event.addFilter('mouseup',    Filters.mouseBtnFilter)
Event.addFilter('mousedown',  Filters.mouseBtnFilter)
Event.addFilter('click',      Filters.mouseBtnFilter)

Event.addFilter('keyup',      Filters.keyFilter)
Event.addFilter('keydown',    Filters.keyFilter)
Event.addFilter('keypress',   Filters.keyFilter)


Event.addFilter('mouseup',    Filters.modifierKeyFilter)
Event.addFilter('mousedown',  Filters.modifierKeyFilter)
Event.addFilter('click',      Filters.modifierKeyFilter)
Event.addFilter('keyup',      Filters.modifierKeyFilter)
Event.addFilter('keydown',    Filters.modifierKeyFilter)
Event.addFilter('keypress',   Filters.modifierKeyFilter)


// document.observe("dom:loaded", function(){
//   Behavior.add("#happy::mousedown(right)", function(e){console.log('right click', this, e)} )
//   Behavior.add("#foo::keypress(LEFT)", function(e){console.log('left arr', this, e)} )
//   Behavior.add("#foo::keyup(a -shift)", function(e){console.log('a', this, e)} )
// })
