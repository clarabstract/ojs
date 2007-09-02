var FireLog = {
  dom: {},
  init: function() {
    if(!this.done_inti) {
      this.dom.main = $('firelog')
      this.dom.main.innerHTML = '<a href="#" onclick="FireLog.toggle_log(); return false;" id="fl_toggle_log" class="fl_command_link">Show FireLog</a><div id="fl_content" style="display:none;"><h1>Log:</h1><div id="fl_log_area"></div></div>'
      this.dom.content = $('fl_content')
      this.dom.toggle_log = $('fl_toggle_log')
      this.dom.log_area = $('fl_log_area')
      this.visisble = false
      this.done_inti = true
    }
    
  },
  log: function() {
    this.init()
    this.show_log()
    str = $A(arguments).collect(this.Formatter.format.bind(this.Formatter)).join(this.Formatter.span("mrkr", ", "))
    new Insertion.Top(this.dom.log_area,'<div class="fl_log_row">'+str+'</div>')
  },
  show_log: function() {
    if(!this.visible) {
      this.toggle_log()
    }
  },
  toggle_log: function() {
    if(this.visible) {
      this.dom.main.className = ""
      this.dom.content.hide()
      this.dom.toggle_log.innerHTML = "Show FireLog"
      this.visible = false
    }else{
      this.dom.main.className = "fl_visible"
      this.dom.content.show()
      this.dom.toggle_log.innerHTML = "Hide FireLog"
      this.visible = true
    }
  },
  Formatter: {
    format: function(e, detail) {
      detail = detail || 0;
      var preview_content;
      if(e == null) {
        return this.span("null", e)
      }
      switch(typeof( (typeof(e.valueOf) == "function") ? e.valueOf() : e)) {
        case "boolean":
          return this.a("bool",e,e)
        break
        case "number":
          return this.a("num",e,e)
        break
        case "string":
          return this.a("str",e, this.span("strquo",'&ldquo;')+e.escapeHTML()+this.span("strquo",'&rdquo;'))
        break
        case "function":
          return this.a("func", e, this.getFuncName(e))
        break
        case "object":
          if(e instanceof Array) {
            preview_content = e.collect(this.format.bind(this)).join(this.span("mrkr",", "));
            return this.span("arr", this.a("arrlnk", e, "Array") + this.span("mrkr", "[") + preview_content + this.span("mrkr", "]"))
          } else {
            preview_content = this.span("mrkr", "{") + this.getObjPreview(e).join(this.span("mrkr", ", ")) + this.span("mrkr", "}")
            return this.span("obj", this.a("objlnk", e, this.getObjName(e)) + preview_content )
          }
        break
        default:
          throw "[FireLog] Unrecognized type (this really shouldn't happen): " + typeof(e.valueOf())
      }
    },
    getFuncName: function(e) {
      return e.toString().match(/\(?([^\{]+)/)[1].strip()
    },
    getObjName: function(e) {
      var m;
      try {
        if(typeof(e.constructor) == "function" && (m=e.constructor.toString().match(/function ([^\(]+)/))) {
          return m[1]
        }
        if(typeof(e.toString) == "function" && (m = e.toString().match(/\[object ([^\]]+)/))) {
          return m[1]
        }
        return "Object"
      } catch(e) {
        return "FactoryObject"
      }
    },
    getObjPreview: function(e) {
      return [""]
    },
    span: function(css_class, content) {
      return '<span class="l_'+css_class+'">'+content+'</span>'
    },
    ref_counter:0,
    a: function(css_class, obj_ref, content) {
      oid = this.ref_counter
      this.ref_counter++
      FireLog.Inspector.refs[oid] = obj_ref
      return '<a class="l_'+css_class+'" onclick="FireLog.Inspector.inspect('+oid+', this);return false;" href="#">'+content+'</a>'
    }
  },
  Inspector: {
    refs:{},
    dom:{},
    previous_crumbs:[],
    div_html: '<div id="fl_inspector"><div id="fl_crumbs"></div><a href="#" onclick="FireLog.Inspector.collapse(); return false" id="fl_collapse_inspector" class="fl_command_link">Collapse Inspector</a><h2>Inspecting <span id="fl_inspected">nothing</span>:</h2><div id="lf_iprop_container"></div><a href="#" onclick="FireLog.Inspector.expand(); return false" id="fl_expand_inspector" class="fl_command_link" style="display:none;">Expand Inspector</a></div>',
    inspect: function(refid, srcel) {
      var obj = this.refs[refid], srctype = this.showInspector(srcel), active_crumb, stop_pushing_prev_crumbs;
      if( srctype == "log_row") {
        this.crumbs = [refid]
        active_crumb = 0
        this.previous_crumbs = []
      } else if( srctype == "crumbs"){
        this.previous_crumbs = []
        crumb_refid = Number($(srcel).up(".crumb").getAttribute("_refid"))
        this.crumbs.each(function(c,i){
          if(!stop_pushing_prev_crumbs) {
            this.previous_crumbs.push(c)
          }
          if(c == crumb_refid) {
            active_crumb = i
            stop_pushing_prev_crumbs = true
          }
        }.bind(this))
      } else {
        if(this.previous_crumbs.length > 0) this.crumbs = this.previous_crumbs
        this.crumbs.push(refid)
        active_crumb = this.crumbs.length - 1
      }
        $('fl_crumbs').innerHTML = this.crumbs.collect(function(rid, idx) {
          var e = this.refs[rid];
          var cname = (idx == active_crumb) ? "crumb active" : "crumb"
          return '<span class="'+cname+'" _refid="'+rid+'">' + FireLog.Formatter.format(e) + "</span>"
        }.bind(this)).join(FireLog.Formatter.span("crumb_arrow", " &rarr; "))
      this.dom.inspected.innerHTML = FireLog.Formatter.format(obj)
      $('lf_iprop_container').innerHTML = '<table id="lf_iprops" cellspacing="0" cellpadding="0"></table>'
      this.dom.props = $('lf_iprops')
      for(p in obj) {
        var newrow = this.dom.props.insertRow(-1)
        var propname_cell = newrow.insertCell(-1)
        propname_cell.className = "fl_propname"
        propname_cell.innerHTML = p
        var val_cell = newrow.insertCell(-1)
        val_cell.innerHTML = FireLog.Formatter.format(obj[p])
      }
      if(typeof(obj.valueOf? obj.valueOf() : obj) == "function") {
        new Insertion.Before(this.dom.props, '<div id="fl_func_source"><pre>'+obj.toString().escapeHTML()+"</pre></div>")
      }
      
    },
    showInspector: function(el) {
      var source = "inspector";
      do {
        if(pn = el.parentNode) {
          el = pn
        }else{
          source = "external"
          break;
        }
        if(el.id == "fl_crumbs") source = "crumbs"
      } while(!(el.className == "fl_log_row") && !(el.id == "fl_inspector"))
      if(el.className == "fl_log_row" || source == "external") {
          if(this.dom.main) this.dom.main.remove()
          if(source == "external") {
            FireLog.show_log();
            new Insertion.Top(FireLog.dom.log_area, this.div_html)
          } else {
            new Insertion.After(el, this.div_html)
          }
          this.dom.main = $('fl_inspector')
          this.dom.inspected = $('fl_inspected')
          $('lf_iprop_container').innerHTML = '<table id="lf_iprops" cellspacing="0" cellpadding="0"></table>'
          this.dom.props = $('lf_iprops')
          source = "log_row";
      } else {
        if(f = $("fl_func_source")) f.remove()
      }
      this.expand()
      return source;
    
    },
    collapse: function() {
      this.dom.props.hide()
      if(f = $("fl_func_source")) f.hide()
      $('fl_collapse_inspector').hide()
      $('fl_expand_inspector').show()
    },
    expand:  function() {
      this.dom.props.show()
      if(f = $("fl_func_source")) f.show()
      $('fl_collapse_inspector').show()
      $('fl_expand_inspector').hide()
    }
  }
  
}
var log = function() {
  FireLog.log.apply(FireLog, arguments)
}

Event.observe(window, 'load', function() {
  FireLog.init()
})