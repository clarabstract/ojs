Test.BDD = {
  extend:  function(obj) {
    Object.extend(obj, Test.BDDMethods)
    return obj
  },
  wrapperFor: function(obj, method) {
    return function(proceed) {
      // Wrappers will still be around after a previous test, so sometimes we'll get here even if there are no actual checks to be done
      var objChecks, myCheck;
      if((objChecks = obj.__bddChecks) && (myCheck = objChecks[method])) {
        myCheck.actualCount++;
        myCheck.actualArgs[myCheck.actualCount] = Array.prototype.slice.call(arguments, 1)
      }
      return proceed.apply(this, Array.prototype.slice.call(arguments,1))
    }
  },
  shouldReceive: function(test, functionName) {
    var check = new Test.BDD.Check({object: this, message:functionName, checked: false})
    check.exactly(1)
    this.__bddChecks = this.__bddChecks || {}
    this.__bddChecks[functionName] = check
    Test.BDD.checkedObjects.push(this)
    //Only wrap once!
    if(!this[functionName]._bddWrapped) {
      this[functionName] = this[functionName].wrap(Test.BDD.wrapperFor(this,functionName))
      this[functionName]._bddWrapped = true
    }
    return check
  },
  shouldNotReceive: function(test, functionName) {
    return this.shouldReceive(test, functionName).exactly(0)
  },
  runChecks: function(test) {
    var checks = Test.BDD.checkedObjects
    for (var i=0; i < checks.length; i++) {
      var checkedObj = checks[i]
      for(var checkedFunction in checkedObj.__bddChecks) {
        var check = checkedObj.__bddChecks[checkedFunction]
        var cr = check.countCheck()
        if( cr.result ) {
          test.pass()
        } else {
          test.fail("Expected "+checkedObj+" to receive "+checkedFunction+"() "+cr.message+" "+check.expectedCount+" times, but it was received "+check.actualCount+" times.")
        }
        if(check.actualCount > 0 && check.expectedArgs) {
          test.assertEnumEqual(check.expectedArgs, check.actualArgs.last(), "Arguments for "+checkedObj+"."+checkedFunction+"()")
        }
        if(check.actualCount > 0 && check.expectedArgumentSeries) {
          for(callNum in check.expectedArgumentSeries) {
            var expectedArgs = check.expectedArgumentSeries[callNum]
            if(!Object.isArray(expectedArgs)) expectedArgs = [expectedArgs]
            test.assertEnumEqual(expectedArgs, check.actualArgs[callNum], "Arguments for "+checkedObj+"."+checkedFunction+"(), on call #"+callNum)
          }
        }
        if(check.actualCount > 0 && check.verifier) {
          check.verifier.apply(test, check.actualArgs.last())
        }
        if(check.actualCount > 0 && check.verifierSeries) {
          for(callNum in check.verifierSeries) {
            check.verifierSeries[callNum].apply(test, check.actualArgs[callNum])
          };
        }
      }
    }
  }
}
Test.BDD.Check = Class.create({
  initialize: function(setup) {
    Object.extend(this, setup)
    this.actualArgs = []
    this.actualCount = 0
  },
  withArgs: function() {
    this.expectedArgs = $A(arguments)
    return this;
  },
  eachTimeWithArguments: function(argSeries) {
    this.expectedArgumentSeries = argSeries
    return this;
  },
  verifying: function(verifier) {
    this.verifier = verifier
    return this;
  },
  verifyingEachTime: function(verifiers) {
    this.verifierSeries = verifiers
    return this;
  },
  exactly: function(count) {
    this.expectedCount = count
    this.countCheck = function() {
      return {result: this.actualCount == this.expectedCount, message:"exactly"}
    }
    return this;
  },
  atLeast: function(count) {
    this.expectedCount = count
    this.countCheck = function() {
      return {result: this.actualCount >= this.expectedCount, message: "at least"}
    }
    return this;
  },
  atMost: function(count) {
    this.expectedCount = count
    this.countCheck = function() {
      return {result: this.actualCount <= this.expectedCount, message: "at most"}
    }
    return this;
  },
  once: function(count){
    return this.exactly(1)
  },
  twice: function(count){
    return this.exactly(2)
  },
  anyNumberOfTimes: function() {
    return this.atLeast(0)
  },
  times: function() {
    return this // it's just a syntax nicety
  }
  
})

// Comment it out if it bothers you and use the longer name
$T = Test.BDD.extend


// Hooking into the test runner
Test.Unit.Testcase.prototype.run = Test.Unit.Testcase.prototype.run.wrap(
  function (proceed) {
    if(Test.BDD.checkedObjects) {
      for (var i=0; i < Test.BDD.checkedObjects.length; i++) {
        delete Test.BDD.checkedObjects[i].__bddChecks
      };      
    }
    Test.BDD.checkedObjects = []
    Test.BDDMethods.shouldReceive = Test.BDD.shouldReceive
    Test.BDDMethods.shouldNotReceive = Test.BDD.shouldNotReceive
    var returning = proceed.apply(this, Array.prototype.slice.call(arguments,1))
    Test.BDD.runChecks(this)
    return returning;
  }
)
