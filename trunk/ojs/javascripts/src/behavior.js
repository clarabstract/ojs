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
  
To-Do:
  - Allow a handler to be called for an unknown event...?
  - "::init" pseudo-event - basically just a function that gets executed immediately on all matching events (defer to $().wrap, maybe?)
  - Configure({attrib: "blah"}) function-factory that sets an attribute on an element
  - or better yet just have a "::configure" pseudo instead... Combined with KVC-style Element.get()  it would be rather handy
  - "::submit|valid" for alternation
  - "::submit>first"
  - allow delegated events to 'bubble' anyway
  - Maybe the "::test:click-direct" methods can just be called "on_test_click-direct" or something? meh...

Problem:
Concurrent observing of common actions that MAY need to be ordered a certain way
e.g.
  usually:    submit -> normal send
  but maybe:  submit -> send ajax
  but maybe:  submit -> validate -> normal send
  but maybe:  submit -> validate -> send ajax
  but NEVER:  submit -> send ajax -> validate

Maybe just rely on specific sequence... ?
  -> Yes. Sequence is your business.

  
 

Before/after?

*/
// The main 'public' module
Behavior = {
  // Many ways to call - see behavior_test.html and main docs
  add: function(selector, handler) {
    if(Object.isString(selector)) {
      if(Object.isArray(handler)) {
        //Applying several handlers for a selector
        for (var i=0; i < handler.length; i++) {
          Behavior.add(selector, handler[i])
        };
        return;
      }
      if(r = selector.match(/(.*)::([-\w\d_:]*)$/)){
        //Applying a handler function directly
        Event.observeElements(r[1], r[2], handler)
      } else {
        //Applying a behavior class.
        for(m in handler) {
          if(r = m.match(/^::(.*)/)) {
            handler[m] = handler[m].bind(handler)
            Event.observeElements(selector, r[1], handler[m]) 
          }
        }
      }   
    } else {
      //Configuring many selectors at once
      for( s in selector) {
        Behavior.add(s, selector[s])
      }
    }
  }
}


// The event caches
EventCache = {}
DelegatesBySelectorCache = {}

// Some handy extentions

// Removes el from array in-place
Array.prototype.remove = function(el) {
  for (var i = this.length - 1; i >= 0; i--){
    if(this[i] == el) this.splice(i,1)
  };
  return this
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
    $$(sel).invoke('observe', eventName, handler);
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
            matchingElements[i].observe(eventName, handlers[j])
          };
        }
      };
    }
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
  observeElements: function(sel, eventName, handler) {
    var r = eventName.match(/(.*)-(direct|delegated)$/) || []
    eventName = r[1] || eventName
    var forceMethod = r[2]
    var observeMethod = Event.doesNotBubble[eventName] ? Event.observeElementsDirectly : Event.observeElementsWithDelegation
    if(forceMethod == "direct") observeMethod = Event.observeElementsDirectly
    if(forceMethod == "delegated") observeMethod = Event.observeElementsWithDelegation
    // console.log("Observe", sel, "::"+eventName, observeMethod == Event.observeElementsDirectly ? "direct" : "delegated" )
    observeMethod(sel, eventName, handler)
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
              if(ev.stopped) return false;
              selHandlers[i].call(element, ev)
            }
          }
        }
      }
      Event[delegateHandlerName].handlers = {}
    }
    return delegateHandlerName
  }
}
Object.extend(Event, EventExtentions)
Object.extend(Event.doesNotBubble, Event._neverBubbles)

