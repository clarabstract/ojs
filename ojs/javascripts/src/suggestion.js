/*  Suggestion Modules (i.e. auto-complete behaviors for text boxes)

    Instead of providing a monolithic Suggestion class, this behavior is broken in modules with intentionally limited responsibilities.
    
    DataArray
      Stores an array of data.
      
      + Selection
      Stores a selection inside an array.
      
      + TableRender
      Renders an array as an html table, including selection.
      
      
      
    
  
  

*/


/* Observe Tokens Behavior
  
  Attatch to text fields.
  
  A "token" is an item in a space-delimited string. A token can contain a space if enclosed by quotes.
  
  Fires 2 custom events:
    token:active
      Fired when the caret enters a token, or modifies an existing one (or even types a new one).
      Event Memo:
        position:     The character position of the token's start
        content:      The token string itself
      
    token:inactive
      Fired when when the caret is no longer inside a token (usually having just left one)
  
  Constructor options:
    new ObserveTokens(regex)
    regex:
      A regex to split tokens into.
*/
ObserveTokens = Class.create({
  initialize: function(regex) {
    this.regex = regex || (/[^ "]+|"[^"]+"|"[^"]+$/g)
    this["::focus"] = this.checkToken.bind(this)
    this["::keyup"] = this.checkToken.bind(this)
    this["::click"] = this.checkToken.bind(this)
  },
  "::blur": function(ev) {
    ev.element().fire("token:inactive")
  },
  checkToken: function(ev){
    var el = ev.element()
    if(!el.tagName) return; //Firefox will focus() on alt-tab - el will == document
    var cP = el.getCaretPosition();
    token = {}
    while(r = this.regex.exec(el.value)) {
        if(r.index < cP && cP <= (r.index + r[0].length)) {
          token.position = r.index
          token.content = r[0]
        }
    }
    if(token.content) {
      el.fire("token:active", token)
    } else {
      el.fire("token:inactive")
    }
  }
})





/* A table that can be generated form an array of rows and is aware of selections.
*/
SelectionBox = Class.create({
  initialize: function(name) {
    this.name = name
    this._createTable();
    this.clear()
  },
  clear: function() {
    this.table.innerHTML = "";
    this.selection = null;
    this.selectionEl = null;
  },
  _createTable: function() {
    Element.insert(document.body, '<table id="'+this.name+'" style="display:none;"></table>')
    this.table = $(this.name)
    this.table.observe('mouseout', this.select.bind(this, null))
  },
  displayForElement: function(element, offsetLeft, offsetTop) {
    this.element = element;
    offsetTop = offsetTop || 0
    offsetLeft = offsetLeft || 0
    this.show()
    this.table.clonePosition(element, {
      setWidth: false,
      setHeight: false,
      offsetTop: offsetTop,
      offsetLeft: offsetLeft
    })
  },
  selectNext: function() {
    var index = this.selection + 1;
    if(this.selection == null || index >= this.table.rows.length) {
      index = 0
    }
    this.select(index)
  },
  selectPrevious: function() {
    var index = this.selection - 1;
    if(this.selection == null || index < 0) {
      index = this.table.rows.length - 1
    }
    this.select(index)
  },
  selectCurrent: function(ev){
    ev && ev.stop()
    this.element.fire('box:select', this)
  },
  select: function(index) {
    if(this.selectedEl) {
      this.selectedEl.removeClassName('selected')
      this.selectedEl = null;
      this.selection = null;
    }
    try {
      this.selectedEl = $(this.table.rows[index])
      this.selectedEl.addClassName('selected')
      this.selection = index 
    } catch(e) {}
  },
  show: function() {
    this.table.show()
  },
  hide: function() {
    this.element = null;
    this.table.hide()
  },
  setData: function(rows) {
    this.clear()
    for (var i=0; i < rows.length; i++) {
      this.insertRow(rows[i])
    };
  },
  insertRow: function(row) {
    var rowEl = $(this.table.insertRow(-1));
    if(Object.isArray(row)) {
      for (var i=0; i < row.length; i++) {
        this.insertCell(rowEl, row[i])
      }
    } else {
      for (col in row) {
        this.insertCell(rowEl, row[col], col)
      }
    }
    rowEl.data = row;
    var index = this.table.rows.length - 1;
    rowEl.observe('mouseover', this.select.bind(this, index ))
    rowEl.observe('mousedown', this.selectCurrent.bind(this))
  },
  insertCell: function(rowEl, data, colName) {
    var cellEl = rowEl.insertCell(-1);
    cellEl.innerHTML = data;
    cellEl.className = colName;
  }
})

SelectionBox.suggestions = function() {
  return SelectionBox._suggestions || (SelectionBox._suggestions = new SelectionBox('suggestions'))
}

AjaxDataSource = Class.create({
  initialize: function(url, options){
    this.url = url;
    this.options = options || {}
    this.configureAjax()
  },
  configureAjax: function() {
    this.options.onSuccess = this.dataUpdated.bind(this);
  },
  runQuery: function(query){
    var options = this.options;
    options.parameters = query;
    request = new Ajax.Request(this.url, options)
  },
  dataUpdated: function(transport) {
    this.setData(transport.responseJSON)
  },
  setData: function(data) {
    console.log('got data: ',data)
    this.data = data
  }
})

tagDS = new AjaxDataSource("data.json")

CacheQueries = function(ds) {
  ds._queryCache = []
  Wrap(ds, 'runQuery', function(runQuery, query) {
    query = Object.toQueryString(query)
    var data;
    if(data = this._queryCache[query]) {
      this.setData(data)
    } else {
      return runQuery(query);
    }
  })
  Wrap(ds, 'dataUpdated', function(dataUpdated, transport) {
    var data = transport.responseJSON
    this._queryCache[transport.request.body] = data
    this.setData(data)
  })
  ds.configureAjax()
}

CacheQueries(tagDS)

tagSuggestions = {
  setPrefix: function(prefix) {
    new Ajax.Request('data.json',{
      onSuccess: function(t) {
        this.setSuggestions(t.responseJSON)
      }.bind(this)
    })
  },
  setSuggestions: function(suggestions){
    this.suggestions = suggestions;
  }
}


Behavior(".tag", new AutoComplete({
  dataSource:     new AjaxDataSource("/whatever"),
  selectionBox:   $('mySelection')
}))

AutoComplete = BehaviorModule({
  initialize: function(config) {
    this.config = config || {};
    this.config.selectionBox.setDataSource(this.dataSource)
  },
  "::element:configure": function(ev){
    
  }
})

ShowSuggestions = Class.create({
  initialize: function(){
    doAfter(tagSuggestions, 'setSuggestions', SelectionBox.suggestions().setData.bind(SelectionBox.suggestions()))
    this["::keypress"] = this.supressActionForSpecialKeys
    this["::keyup"] = this.supressActionForSpecialKeys
  },
  supressActionForSpecialKeys: function(ev) {
    switch(ev.keyCode){
      case Event.KEY_UP:
      case Event.KEY_DOWN:
      case Event.KEY_RETURN:
        ev.stop()
      break;
    }
  },
  "::box:select": function(ev) {
    var selection = ev.memo
    var val = selection.element.value;
    var token = selection.element.currentToken;
    var tokenEnd = token.position + token.content.length
    selection.element.value = val.slice(0,token.position) + selection.selectedEl.data[0] + val.slice(tokenEnd);
    selection.element.setCaretPosition(token.position + selection.selectedEl.data[0].length)
    selection.hide()
  },
  "::token:active": function(ev) {
    var el = ev.element()
    el.currentToken = ev.memo
    var cOffset = el.getCharOffset(ev.memo.position)
    tagSuggestions.setPrefix(ev.memo.content)
    SelectionBox.suggestions().displayForElement(el, cOffset.left, cOffset.top)
  },
  "::token:inactive": function(ev) {
    SelectionBox.suggestions().hide()
    ev.element().currentToken = null;
  },
  "::keydown(ESC)": function(ev){
    SelectionBox.suggestions().hide()
    ev.stop()
  },
  "::keydown(UP)": function(ev) {
    SelectionBox.suggestions().selectPrevious()
    ev.stop()    
  },
  "::keydown(DOWN)": function(ev) {
    SelectionBox.suggestions().selectNext()
    ev.stop()    
  },
  "::keydown(RETURN)": function(ev) {
    SelectionBox.suggestions().selectCurrent()
    ev.stop() 
  }
})
