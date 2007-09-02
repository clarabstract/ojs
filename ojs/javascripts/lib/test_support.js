var TestSupport = {tests:{}, result_sources:[], assertions:{},
  init_prelim: function() {
    if(!TestSupport.inited_prelim) {
      new Insertion.After($('rez_container'),'<div id="pr_container"><h2>Preliminary Results:</h2><table id="prelim_results"><tr><th>Test</th><th>Result</th><th>&nbsp;</th></tr></table><textarea id="all_results_src" onfocus="$(this).select()"></textarea></div>')
      TestSupport.inited_prelim = true
    }
  },
  write_result: function(tname, trez) {
    TestSupport.init_prelim()
    var new_row = $('prelim_results').insertRow(-1)
    var tname_cell = new_row.insertCell(-1)
    tname_cell.className = "test_name"
    tname_cell.innerHTML = tname;
    var result_cell = new_row.insertCell(-1)
    result_cell.className = "test_result"
    result_cell.innerHTML = FireLog.Formatter.format(trez)
    var result_source_cell = new_row.insertCell(-1)
    result_source_cell.className = "result_source"
    var rez_src = 'assert_result_for("'+tname+'", '+TestSupport.getSource(trez)+');'
    TestSupport.result_sources.push(rez_src)
    result_source_cell.innerHTML = '<input type="text" onfocus="$(this).select()" value="'+rez_src+'" />'
  },
  getSource: function(obj) {
    return Object.toJSON(obj)
    // if(obj == null) return "null"
    // return (obj.toJSON ?  obj.toJSON() : obj.toString() )
  },
  run_test: function(tname) {
    var row = $('test_results').insertRow(-1)
    var actual = TestSupport.tests[tname]();
    var expected = TestSupport.assertions[tname];

    var tname_cell = row.insertCell(-1), tstatus_cell = row.insertCell(-1), extra_cell = row.insertCell(-1)
    tname_cell.className = "test_name"
    tstatus_cell.className = "test_status"
    extra_cell.className = "test_extra"
    tname_cell.innerHTML = tname;
    if(TestSupport.compare(actual, expected)) {
      row.className = "passed_test"
      tstatus_cell.innerHTML = "Passed"
    } else {
      row.className = "failed_test"
      tstatus_cell.innerHTML = "Failed"
      extra_cell.innerHTML = "Expected " + FireLog.Formatter.format(expected) + ", but got " + FireLog.Formatter.format(actual) + "."
    }
  },
  compare: function(a ,b ) {
    if((a instanceof Array) && (b instanceof Array)) {
      if(a.length != b.length) return false
      for (var i = a.length - 1; i >= 0; i--){
        if(!arguments.callee(a[i],b[i])) return false //recurse as needed
      }
      return true
    } else {
      return (a == b)
    }
  }
}
TestSupport.stubs = []
TestSupport.Stub = function(obj, prop, new_value) {
  this.obj = obj
  this.prop = prop
  this.old_value = obj[prop]
  obj[prop] = new_value
}
TestSupport.unstub = function () {
  for (var i = TestSupport.stubs.length - 1; i >= 0; i--){
    var stub = TestSupport.stubs[i]
    stub.obj[stub.prop] = stub.old_value;
  };
}

Event.observe(window, 'load', function() {
  var files_str = '<ul id="test_scripts">'
  $$('script').pluck("src").each(function(s){
    var m;
    if(m = s.match(/\/src\/([-\w]+\.js)$/))
      files_str += "<li>" + m[1] + "</li> "
  })
  files_str += "</ul>"
  new Insertion.Top(document.body, files_str)
  var test_title = document.location.pathname.match(/\/test\/([-\w]+)\.html$/)[1].split("_").invoke("capitalize").join(" ")
  document.title = test_title
  new Insertion.Top(document.body, "<h1>"+test_title+"</h1>")
  new Insertion.After($('test_content') || $('test_scripts'),'<div id="rez_container"><h2>Test Results:</h2><table id="test_results"><tr><th>Test</th><th>Status</th><th></th></tr></table></div>')
  $H(TestSupport.tests).each(function(pair) {
    var test_name = pair[0], test_func = pair[1], test_result;
    if(TestSupport.assertions[test_name] || TestSupport.assertions[test_name] === null || TestSupport.assertions[test_name] === false) {
      TestSupport.run_test(test_name)
    } else {
     TestSupport.write_result(test_name, test_func()) 
    }
  })
  if(TestSupport.result_sources.length > 0 )   $('all_results_src').innerHTML = TestSupport.result_sources.join("\n")
  TestSupport.unstub();
})

function test(test_name, test_func) {
  TestSupport.tests[test_name] = test_func
}

function assert_result_for(tname, trez) {
  TestSupport.assertions[tname] = trez
}

function stub(obj, prop, new_value) {
  TestSupport.stubs.push(new TestSupport.Stub(obj, prop, new_value))
}
function mock_to_verify(obj, prop) {
  stub(obj, prop, function() {
    obj["__call_values_for_"+prop] = $A(arguments).collect(function(arg){
      return arg ? arg : null
    })
  })
}
function verify(obj, prop) {
   return obj["__call_values_for_"+prop]
}