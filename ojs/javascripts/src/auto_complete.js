/*

AutoComplete
  * shouldComplete function
  * selectionMenu class
  - show_menu
      show_menu? yes:
        display auto complete
        cede key event control to selection box
  
SelectionBox
  - intercept certain events for the textbox
  
DataSource
  .query(params, answerCallback)
  answerCallback(params, answer)
  
*/

MonitorChange = Behavior.create("change:value", {
  initialize: function() {
    // keydown AND keypress are required due to opera/ie mess
    this.wireToEvents("recordValue","keydown", "keypress", "mousedown")
    this.wireToEvents("checkValue", "keyup", "mouseup")
  },
  recordValue: function(element, event) {
    element.originalValue = this.getValue(element)
  },
  checkValue: function(element, event) {
    if(element.originalValue != this.getValue(element)) this.fire(element);
  },
  fire: function(element) {
    element.fire(this.constructor.classIdentifier)
  },
  getValue: Form.Element.getValue
})

DataSource = {}
// Abstract Base class - defines minimum protocol
DataSource.Base = Class.create({
  query: Prototype.emptyFunction, // (params, updateCallback)
  abort: Prototype.emptyFunction,
  yieldResults: function(updateCallback, results) {
    updateCallback(results)
  }
})
DataSource.Ajax = Class.create(DataSource.Base, {
  initialize: function(url, ajaxOptions) {
    this.url = url;
    this.ajaxOptions = ajaxOptions || {};
    this.ajaxOptions.parameters = this.ajaxOptions.parameters || {};
  },
  query: function(params, updateCallback) {
    Object.extend(this.ajaxOptions.parameters, params || {} )
    this.ajaxOptions.onComplete = this.ajaxComplete.bind(this, updateCallback);
    console.log(this.url)
    this.currentRequest = new Ajax.Request(this.url, this.ajaxOptions)
  },
  abort: function() {
    this.currentRequest.transport.abort();
  },
  ajaxComplete: function(updateCallback, transport, json) {
    this.yieldResults(updateCallback, transport.responseJSON)
  }
})

DataSource.Extentions = {}

// Ensures that when a new query is fired, any existing query are stopped and don't run their updateCallback
// Only makes sense for Ajax-based DataSource
DataSource.Extentions.NonConcurrent = {
  query: function($super, params, updateCallback) {
    if(this.currentRequest) this.abort();
    $super(params, updateCallback);
  },
  abort: function() {
    var _request = this.currentRequest;
    this.currentRequest = null;
    _request.transport.abort();
  },
  ajaxComplete: function($super, updateCallback, transport, json) {
    if(this.currentRequest == transport.request) $super(updateCallback, transport, json)
  }
}

$processing = { }

// Cache queries for the same params (serialized with Object.toQueryString)
DataSource.Extentions.QueryCaching = {
  initialize: function($super) {
    $super.apply(this, Array.prototype.slice.call(arguments, 1))
    this.queryCache = {}
  },
  query: function($super, params, updateCallback) {
    var cachedValue, serializedParams = Object.isString(params) ?  params : Object.toQueryString(params);
    if(cachedValue = this.queryCache[serializedParams]) {
      if(cachedValue == $processing) { 
      } else {
        this.yieldResults(updateCallback, cachedValue) 
      }
    } else {
      $super(params, updateCallback);
      this.currentRequest.queryParams = serializedParams;
      this.queryCache[serializedParams] = $processing;
    }
  },
  
  abort: function() {
    this.currentRequest = null;
  },
  ajaxComplete: function($super, updateCallback, transport, json) {
    this.queryCache[transport.request.queryParams] = transport.responseJSON;
    $super(updateCallback, transport, json)
  }
}


// Ajax data source for AutoComplete
DataSource.Ajax.AutoComplete = Class.create( 
                                Class.create(
                                  DataSource.Ajax, 
                                  DataSource.Extentions.NonConcurrent),
                                DataSource.Extentions.QueryCaching)
  




Element.Extentions = Element.Extentions || {}

Element.Extentions.DisplayData = {
  setData: function(data) {
    this.innerHTML = "";
    data.each(this.addRecord, this)
  },
  addRecord: function(record, index) {
    this.insert(this.recordTemplate(record))
    var newElement = this.lastChild
    newElement.record = record
    return this.lastChild
  }
}
Element.Extentions.DropDown = {
  attachToElement: function(element, positionOptions) {
    this.clientElement = element;
    this.show()
    positionOptions = positionOptions || {};
    var options = {setHeight: false, offsetTop: 0};
    Object.extend(options, positionOptions);
    options.offsetTop = options.offsetTop + element.offsetHeight;
    this.clonePosition(element, options);
    Behavior.add(this.clientElement, {
      "::keydown(DOWN)":  [this.markNext.bind(this), Event.stop],
      "::keydown(UP)":    [this.markPrevious.bind(this), Event.stop],
      "::keydown(RETURN)":[this.selectMarked.bind(this), Event.stop],
      "::keydown(ESC)":   [this.hide.bind(this), Event.stop],
      "::blur":           this.hide.bind(this),
      "::keyup(DOWN)":    Event.stop,
      "::keyup(UP)":      Event.stop,
      "::keyup(RETURN)":  Event.stop,
      "::keyup(ESC)":     Event.stop
    })
    var _base = this;
    var recordElementsOnly = function(fn, ev) {
      var element = ev.element();
      while(!element.record) {
        if(element == _base) return;
        element = element.up()
      }
      fn(element);
    }
    var mark = this.mark.bind(this)
    Behavior.add(this, {
      "::mouseover": recordElementsOnly.curry(this.mark.bind(this)),
      "::mousedown": [recordElementsOnly.curry(this.selectMarked.bind(this)), Event.stop]
    })
  },
  markNext: function() {
    this.mark((this.marked && this.marked.next()) || this.firstChild)
  },
  markPrevious: function() {
    this.mark((this.marked && this.marked.previous()) || this.lastChild)
  },
  selectMarked: function() {
    this.clientElement.fire("dropdown:selected",this.marked)
    this.hide()
  },
  mark: function(element) {
    this.marked && this.marked.removeClassName('marked');
    this.marked = element;
    element.addClassName('marked');
  }
}

//The big deal...
AutoComplete = Behavior.create({
  initialize: function(dataSource, selectionBox) {
    this.wireToEvents("completeCurrentWord", "change:value")
    this.wireToEvents("completionSelected", "dropdown:selected")
    this.dataSource = dataSource
    this.selectionBox = selectionBox
  },
  addedToSelector: function(selector){
    Behavior.add(selector, new MonitorChange()) 
  },
  attachedToElement: function(element) {
    // DataBinding.addAcessor(element, "currentWord")
  },
  completeCurrentWord: function(element, event) {
    this.currentWord = this.getCurrentWord(element)
    this.currentElement = element
    this.dataSource.query({prefix: this.currentWord}, this.completionsForWord.bind(this))
  },
  getCurrentWord: Form.Element.getValue,
  completionsForWord: function(completions) {
    this.selectionBox.setData(completions)
    this.selectionBox.attachToElement(this.currentElement)
  },
  completionSelected: function(element, ev){
    element.value = ev.memo.record.name
  }
})

