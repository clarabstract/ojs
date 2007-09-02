# This file was used for some benchmarking during development - it's still useful for tweaking but should not be considered part of a test suite or anything like that
puts "loading simulator - SHOULD NOT HAPPEN!"
require 'set'
require 'pp'
require File.join(File.dirname(__FILE__), *%w[lib loader])
reqs = {
  "torrent/show" => %w(prototype.js scriptaculous.js class.js event_dispatcher.js suggestion.js sug_support.js comments.js torrent.js login.js),
  "torrent/edit" => %w(prototype.js scriptaculous.js class.js event_dispatcher.js suggestion.js sug_support.js comments.js torrent_edit.js login.js),
  "torrent/list" => %w(prototype.js scriptaculous.js class.js event_dispatcher.js torrent.js listings.js login.js),
  "discussion/edit" => %w(prototype.js scriptaculous.js class.js event_dispatcher.js suggestion.js sug_support.js comments.js discussion_edit.js login.js),
  "discussion/show" => %w(prototype.js scriptaculous.js class.js event_dispatcher.js suggestion.js sug_support.js comments.js discussion.js login.js),
  "discussion/list" => %w(prototype.js scriptaculous.js class.js event_dispatcher.js discussion.js listings.js login.js),
}

$sizes = { "prototype.js"=>10322,
  "scriptaculous.js"=>15241,
  "class.js"=>2043,
  "event_dispatcher.js"=>78092,
  "suggestion.js"=>44023,
  "sug_support.js"=>32092,
  "comments.js"=>87621,
  "torrent.js"=>5339,
  "login.js"=>32241,
  "torrent_edit.js"=>2322,
  "discussion.js"=>14322,
  "discussion_edit.js"=>12442,
  "listings.js"=>52322,
}
class File
  class << self
    alias_method :size_without_mocks, :size
    def size_with_mocks(*args)
      $sizes[args.first] || size_without_mocks(*args)
    end
    alias_method :size, :size_with_mocks
  end
end

class LoadSimulator
  def initialize(reqs, sizes)
    @reqs = reqs
    @sizes = sizes
    @packer = OJS::Packer.new(reqs) 
  end
  def render_page(page, files, use_packs = false)
    new_files = files - @cache.to_a
    if use_packs
      page_packs = @packer.packs_for(page) 
      new_packs = page_packs - @cache.to_a
    end
    @cache.merge(use_packs ? page_packs : new_files)
    num_reqs = use_packs ? page_packs.size : files.size
    total_files = (use_packs ? page_packs.flatten: files).inject(0){|sum,f| sum + File.size(f)}
    total_new_files = (use_packs ? new_packs.flatten: new_files).inject(0){|sum,f| sum + File.size(f)}
    puts "%-19s %2d   requests  %7.2f KB, %7.2f KB new#{", using packs " + page_packs.collect{|p| @packer.packs.index(p)}.join(", ") if use_packs}" % [page, num_reqs , total_files / 1024.00, total_new_files / 1024.00]
    @total_files += total_files
    @total_download += total_new_files
    @total_requests += num_reqs
  end
  def before_render
    @cache = Set.new
    @total_files = 0
    @total_download = 0
    @total_requests = 0
  end
  def after_render 
    pn = @reqs.keys.size
    puts "%-19s %2d   requests  %7.2f KB, %7.2f KB new" % ['Total:', @total_requests , @total_files / 1024.00, @total_download / 1024.00]
    puts "%-20s %2.1f requests  %7.2f KB, %7.2f KB new" % ['Avg/page:', @total_requests.to_f/pn , (@total_files / 1024.00)/pn, (@total_download / 1024.00)/pn]
  end
  def render_naively
    before_render
    puts "Naive render:"
    @reqs.each_pair do |p,f|
      render_page(p,f)
    end
    after_render
  end
  def render_packed
    before_render
    puts "\nPacks:"
    @packer.packs.each_with_index do |pack, i|
      puts "#{i}: #{pack.to_a.join(', ')}"
    end
    puts "\nPacked render:"
    @reqs.each_pair do |p,f|
      render_page(p,f,true)
    end 
    after_render
  end
end

sim = LoadSimulator.new(reqs, $sizes)
sim.render_naively
sim.render_packed

=begin
Results (minimum redownload assuming cache):
                      Cached total  Avg Req/page  Avg fresh page
  No packing           379.32 KB    8.3           267.14 KB
  Aggressive packing  1602.84 KB    1.0           267.14 KB
  Pack threshold 0.9   929.31 KB    2.0           267.14 KB
  Pack threshold 0.3   379.32 KB    1.3           367.30 KB
  Pack threshold 0.5   435.63 KB    2.0           328.96 KB
  Sub packs (0.7, 0.5) 379.32 KB    3.0           267.14
=end