


ObserveTokens = {
  checkToken = function(ev){
    var cP = this.getCaretPosition();
    token = {}
    while(r = (/[^ "]+|"[^"]+"|"[^"]+$/g).exec(this.value)) {
        if(r.index < cP && cP <= (r.index + r[0].length)) {
          token.position = r.index
          token.content = r[0]
        }
    }
    if(token.content) {        
      this.fire("token:active", token)
    } else {
      this.fire("token:inactive")
    }
  },
  "::focus": checkToken.bind(ObserveTokens),
  "::keyup":checkToken.bind(ObserveTokens),
  "::click":checkToken.bind(ObserveTokens),
  "::blur": function() {
    this.fire("token:blur")
  }
}

SuggestionList = {
  html: function() {
    if(!this.box) {
     Element.insert(document.body, '<table id="suggestions"><tbody id="suggestions_container"></tbody></table>')
     this.box = $('suggestions')
     this.box = $('suggestions_container')
    }
    return {box: this.box, container}
  },
  hide: function() {
    this.box.hide()
  },
  clear: function() {
    this.box().update("")
  },
  insert: function(val) {
    this.box().insert("<tr><td>"+val+"</td></tr>")
  },
  select: function(el) {
    if(this.selected) this.selected.removeClassName("selected")
    this.selected = el;
    this.selected.addClassName("selected")
  },
  selectNext: function() {
    var next = (this.selected && this.selected.nextSibling) || this.box().firstChild
    this.select(next)
  },
  selectPrevious: function() {
    var next = (this.selected && this.selected.previousSibling) || this.box().lastChild
    console.log(next)
    this.select(next)
  }
  
  
}

function Suggest(dataProvider) {
  //hacky... fixme
  var showing = null
  return {
    "::token:active": function(ev){
      var token = (ev.memo.content)
      if(showing == token) return;
      
      var cOffset = this.getCharOffset(ev.memo.position)
      SuggestionList.box().setStyle({left:cOffset.x + "px", top:cOffset.y + "px"})
      SuggestionList.box().show()
      SuggestionList.clear()
      dataProvider(token).each(SuggestionList.insert.bind(SuggestionList))
      showing = token;
      console.log(ev.name, ev.memo)
    },
    "::token:inactive": function(ev){
      SuggestionList.box().hide()
      console.log(ev.name, ev.memo)
    },
    "::keydown": function(ev){
      console.log(ev.name, ev.memo)
      switch(ev.keyCode) {
        case Event.KEY_ESC:
          SuggestionList.hide()
        break;
        case Event.KEY_UP:
          SuggestionList.selectPrevious()
        case Event.KEY_DOWN:
          SuggestionList.selectNext()
        break;
      }
    },
    "::keypress": function(ev) {
      switch(ev.keyCode){
        case Event.KEY_UP:
        case Event.KEY_DOWN:
          ev.stop()
        break;
      }
    }
  }
}

