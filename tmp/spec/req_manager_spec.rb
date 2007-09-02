require File.join(File.dirname(__FILE__), *%w[.. lib ojs])
require 'fileutils'
TEST_ROOT =  File.join(File.dirname(__FILE__), *%w[.. test_files ])

module PaclSpecUtils
  class GeneratePacks
    include PaclSpecUtils
    def initialize(expected_packs)
      @expected_packs = expected_packs.collect{|pack| pack.collect{|file| full_file_name(file)}}
    end
    def matches?(jsrm)
      @jsrm = jsrm
      @actual_packs = []
      @pack_files = @jsrm.pack_files.each do |pack_file|
        @actual_packs << @jsrm.class.cache[:pack_content_fyi][pack_file]
      end
      @actual_packs.dup.each do |actual_pack|
        if @expected_packs.include?(actual_pack)
          @expected_packs.delete(actual_pack)
          @actual_packs.delete(actual_pack)
        end
      end
      @actual_packs.empty? && @expected_packs.empty?
    end
    def left_overs
      msg = ""
      msg << "  Unexpected generated packages:\n#{@actual_packs.collect{|p|"    #{p}\n"}}" unless @actual_packs.empty?
      msg << "  Expected packages that were never recieved:\n#{@expected_packs.collect{|p|"    #{p}\n"}}" unless @expected_packs.empty?
      msg << "\n" + Spec::Expectations::Differs::Default.new.diff_as_object(@actual_packs,@expected_packs)
    end
    def failure_message
      "generated packages did not match expected ones:\n#{left_overs}"
    end
    def negative_failure_message
      "generated packages matched expected ones, even though they shouldn't:\n#{left_overs}"
    end
  end

  def generate_page_packs(*expected_packs)
    GeneratePacks.new(expected_packs)
  end
  def full_file_name(file)
    if file[/[^\.]+$/] == "js"
      dir = OJS::options[:js_lib_path]
    elsif
      dir = OJS::options[:ojs_source_path]
    end
    File.join(dir, file)
  end
end

describe OJS::JSReqManager do
  include PaclSpecUtils
  def visit_page_with_reqs(page_name, *files)
    jsrm = OJS::JSReqManager.for_page(page_name)
    files.each do |file|
      jsrm.add_requirement(full_file_name(file))
    end
    jsrm
  end
  before(:each) do
    FileUtils.rm Dir.glob("#{TEST_ROOT}/cache_data/*")
    FileUtils.rm Dir.glob("#{TEST_ROOT}/ojs_packs/*")
    RAILS_ROOT = TEST_ROOT
    OJS.configure({
      :ojs_source_path => "#{TEST_ROOT}/ojs_src",
      :ojs_package_path => "#{TEST_ROOT}/ojs_packs",
      :js_lib_path => "#{TEST_ROOT}/libs",
      :req_cache_dir => "#{TEST_ROOT}/cache_data"
    })
  end
  it "should re-calculate aprioriate packages as pages are visted " do
    #with limited knowledge, can only make 1 pack
    visit_page_with_reqs("foo", *%w(foo.ojs)).should generate_page_packs(%w(prototype.js class.js event_dispatcher.js foundation.ojs common.ojs foo.ojs))
    #detect oportunity for shared pack
    visit_page_with_reqs("bar", *%w(support.ojs bar.ojs)).should generate_page_packs(%w(prototype.js class.js event_dispatcher.js foundation.ojs common.ojs), %w(bar.ojs support.ojs ))
    #detect oportunity for sub pack
    visit_page_with_reqs("baz", *%w(support.ojs baz.ojs)).should generate_page_packs(%w(prototype.js class.js event_dispatcher.js foundation.ojs common.ojs), %w(support.ojs), %w(baz.ojs))
    # with new set of requirements, foo packs should be revised
    visit_page_with_reqs("foo", *%w(foo.ojs)).should generate_page_packs(%w(prototype.js class.js event_dispatcher.js foundation.ojs common.ojs), %w(foo.ojs))
    #as should bar (now with sub packs)
    visit_page_with_reqs("bar", *%w(support.ojs bar.ojs)).should generate_page_packs(%w(prototype.js class.js event_dispatcher.js foundation.ojs common.ojs), %w(support.ojs ), %w(bar.ojs))
    #but baz should stay the same
    visit_page_with_reqs("baz", *%w(support.ojs baz.ojs)).should generate_page_packs(%w(prototype.js class.js event_dispatcher.js foundation.ojs common.ojs), %w(support.ojs), %w(baz.ojs))
  end
end
