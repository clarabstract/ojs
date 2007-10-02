Dependencies.load_once_paths.delete(lib_path)
require 'ojs/ajax_exceptions'
OJS::options[:req_cache_store] = $__ojs_cache_store = OJS::Loader::CacheStores::MultiStore.new("#{RAILS_ROOT}/tmp/ojs/ojs_req_cache.mrshl")

