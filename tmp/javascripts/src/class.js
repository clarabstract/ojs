
function BaseKlass(){};
function Base(){};

BaseKlass.prototype = {
  // Create an instance and run the init() method on it, passing arguments
  create: function() {
    var new_instance = new this._class_function;
    callback(new_instance, 'init', arguments)
    return new_instance;
  },
  //Create a new instance, setting properties, then run the init() method which will recieve no arguments.
  createWith: function(props) {
    var new_instance = new this._class_function;
    for(prop in props) {
      new_instance[prop] = props[prop];
    }
    callback(new_instance, 'init')
    return new_instance;
  },
  // Find or create an instance with prop = propval, then run the init() method which will recieve no arguments.
  findOrCreateBy: function(prop, propval) {
    this._instances = this._instances || {};
    var inst, insts_for_prop = this._instances[prop] || {};
    if(inst = insts_for_prop[propval]) {
      return inst;
    }
    inst = new this._class_function;
    inst[prop] = propval;
    insts_for_prop[propval] = inst;
    this._instances[prop] = insts_for_prop;
    callback(inst, 'init');
    return inst
  },
  // Shortcut for klass.findOrCreateBy("id", id)
  i:function(id){
    return this.findOrCreateBy("id",id)
  },
  // Get the class name (using constructor source)
  name: function(){
    return this._class_function.toString().match(/^\s*function ([^\(]+)/)[1]
  }
};
BaseKlass.prototype._real_constructor = BaseKlass;
Base.klass = new BaseKlass;


//Add +methods+ to +new_obj+, setting a super_method property of a property that's about to be over-written
function _add_methods_with_super(new_obj, methods) {
  for(var m in methods) {
    var super_method = new_obj[m];
    if(super_method) methods[m].super_method = super_method;
    new_obj[m] = methods[m];
  }
}

function define_class(new_class_func, super_klass_func, instance_methods, class_methods) {
  // Make methods optional
  instance_methods = instance_methods || {};
  class_methods = class_methods || {};

  //Rememeber the super_class
  new_class_func.super_class = super_klass_func;
  
  //Start by inheriting super's instance methods
  new_class_func.prototype = new super_klass_func;
  //Add new methods
  _add_methods_with_super(new_class_func.prototype, instance_methods)

  //Remember the real constructor
  new_class_func.prototype._real_constructor = new_class_func;

  //Set-up a klass_function singleton 
  var klass_function = function Klass(){};

  //Have our klass_function inherit from super's klass_function
  klass_function.prototype = new super_klass_func.klass._real_constructor;
  //Add new methods
  _add_methods_with_super(klass_function.prototype, class_methods)

  //Remember the real constructor
  klass_function.prototype._real_constructor = klass_function;
  
  //Have our klass_function remember what class_function they belong to (not inherited)
  klass_function.prototype._class_function = new_class_func;
    
  //Instantiate our klass singleton
  new_class_func.klass = new klass_function;


  //Make a pointer back to the klass singleton for all instances
  //(not truly required, but handy... can also go my_instance.constructor.klass)
  new_class_func.prototype.klass = new_class_func.klass;
  
  //Apply callbacks
  callback(new_class_func.klass, 'defined')
  callback(super_klass_func.klass, 'inherited', [new_class_func])
  
}


