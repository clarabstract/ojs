Binding = {
  bind: function(objA, attrA, objB, attrB) {
    objA[Binding._setterName(attrA)] = objA[Binding._setterName(attrA)].wrap(Binding._setWrapper(objB, attrB))
    objB[Binding._setterName(attrB)] = objB[Binding._setterName(attrB)].wrap(Binding._setWrapper(objA, attrA))
  },
  _setWrapper: function(obj, attr) {
    return function(proceed, val) {
      return obj[Binding._setterName(attr)](val)
    }
  },
  makeGetter: function(obj, attr, fn) {
    obj[Binding._getterName(attr)] = fn || function() {
      return obj[attr]
    }
  },
  makeSetter: function(obj, attr, fn) {
    obj[Binding._setterName(attr)] = fn || function(val) {
      return obj[attr] = val
    }
  },
  makeAccessor: function(obj, attr) {
    Binding.makeGetter(obj, attr)
    Binding.makeSetter(obj, attr)
  },
  _getterName: function(attr) {
    return ('get-'+attr).camelize();
  },
  _setterName: function(attr) {
    return ('set-'+attr).camelize();
  }
}