Element.addMethods({
  // Restores styles to their original state before saveStyles()
  restoreStyles: function(element) {
     return element.setStyle(element._originalStyles)
   },
   // Use to temporarily modify element styles and revert the modifications later (with restoreStyles() )
   // Accepts either a list of styles to remember or a hash which will both save and set new styles.
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
   },
  // returns the horisontal offset in pixels of particular character position in a text field (including any borders or padding)
  // if no position is provided, the current caret position is used
  getCharOffset: function(el, position) {
    position = position == undefined ? el.getCaretPosition() : position;
    if(!el.averagePadding) {
      el.saveStyles({width:0})
      el.averagePadding = el.offsetWidth / 2
      el.restoreStyles()      
    }
    var metric = $('textmetric__')
    if(!metric) {
      metric = new Element("div", {id:"textmetric__"})
      // metric.setStyle({position:"absolute", top:"9px", margin:"0",padding:"0",border:"none"})
      metric.setStyle({position:"absolute", top:"-999px", margin:"0",padding:"0",border:"none"})
      $(document.body).insert(metric)
    }
    // Set styles again only if measuring a different element
    if(metric.measuringElement != el ) {
      metric.measuringElement = el;
      var styles = {}
      $w("font-size font-weight font-family letter-spacing").each(function(prop){
        styles[prop.camelize()] = el.getStyle(prop)
      })
      metric.setStyle(styles)
      metric.innerHTML = "_"
      metric.underscoreWidth = metric.getWidth()
    }
    metric.innerHTML = el.value.slice(0,position).escapeHTML().replace(/ /g, '&nbsp;') + "_"
    return { left:el.averagePadding + metric.getWidth() - metric.underscoreWidth,
             top:el.getHeight() - el.averagePadding }
  },
  getCaretPosition: function (ctrl) {
     if(!ctrl) return null;
     var CaretPos ;
     // IE
     if (document.selection) {
       ctrl.focus();
       var Sel = document.selection.createRange();

       Sel.moveStart ('character', -ctrl.value.length);

       CaretPos = Sel.text.length;
     }else{
       // Firefox
       try {
         if (ctrl.selectionStart || ctrl.selectionStart == '0') CaretPos = ctrl.selectionStart;
       } catch(e) {
         return null
       }
     }
     return (CaretPos);

   },
   setCaretPosition: function(ctrl, pos) {
     if(!ctrl || !pos) return null;
     if(ctrl.setSelectionRange)  {
       ctrl.focus();
       ctrl.setSelectionRange(pos,pos);
     } else if (ctrl.createTextRange) {
       var range = ctrl.createTextRange();
       range.collapse(true);
       range.moveEnd('character', pos);
       range.moveStart('character', pos);
       range.select();
     }
   }
})