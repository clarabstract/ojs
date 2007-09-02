namespace :ojs do
  
  PLUGIN_ROOT = File.dirname(__FILE__) + '/../'
  
  desc 'Installs required javascript files to the public/javascripts directory.'
  task :install do
    FileUtils.mkpath [RAILS_ROOT + '/public/javascripts/lib', RAILS_ROOT + '/public/javascripts/logger']
    FileUtils.cp Dir[PLUGIN_ROOT + '/javascripts/src/*.js'], RAILS_ROOT + '/public/javascripts/lib'
    FileUtils.cp Dir[PLUGIN_ROOT + '/javascripts/lib/firelog.*'], RAILS_ROOT + '/public/javascripts/logger'
  end

  desc 'Removes the javascripts for the plugin.'
  task :remove do
    FileUtils.rm Dir[PLUGIN_ROOT + '/javascripts/src/*.js'].collect { |f| RAILS_ROOT + "/public/javascripts/lib" + File.basename(f)  }
    FileUtils.rm Dir[PLUGIN_ROOT + '/javascripts/lib/firelog.*'].collect { |f| RAILS_ROOT + "/public/javascripts/logger" + File.basename(f)  }
  end
  
  desc 'Removes all temporariy files and caches.'
  task :reset do
    FileUtils.rm Dir[RAILS_ROOT + '/tmp/ojs/*']
    FileUtils.rm Dir[RAILS_ROOT + '/public/javascripts/packs/*']
    FileUtils.rm Dir[RAILS_ROOT + '/public/stylesheets/packs/*']
  end
  
end