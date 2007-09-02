require File.join(File.dirname(__FILE__), *%w[.. lib ojs])
describe OJS::Packer, "with hexagon specific sample requirements" do
  before(:each) do
    @reqs = {
      "torrent/show" => %w(prototype.js scriptaculous.js class.js event_dispatcher.js suggestion.js sug_support.js comments.js torrent.js login.js),
      "torrent/edit" => %w(prototype.js scriptaculous.js class.js event_dispatcher.js suggestion.js sug_support.js comments.js torrent_edit.js login.js),
      "torrent/list" => %w(prototype.js scriptaculous.js class.js event_dispatcher.js torrent.js listings.js login.js),
      "discussion/edit" => %w(prototype.js scriptaculous.js class.js event_dispatcher.js suggestion.js sug_support.js comments.js discussion_edit.js login.js),
      "discussion/show" => %w(prototype.js scriptaculous.js class.js event_dispatcher.js suggestion.js sug_support.js comments.js discussion.js login.js),
      "discussion/list" => %w(prototype.js scriptaculous.js class.js event_dispatcher.js discussion.js listings.js login.js),
    }
    
    @sizes = { "prototype.js"=>10322,
      "scriptaculous.js"=>15241,
      "class.js"=>2043,
      "event_dispatcher.js"=>78092,
      "suggestion.js"=>44023,
      "sug_support.js"=>32092,
      "comments.js"=>87621,
      "torrent.js"=>10322,
      "login.js"=>10322,
      "torrent_edit.js"=>10322,
      "discussion.js"=>10322,
      "discussion_edit.js"=>10322,
      "listings.js"=>10322,
    }.each_pair do |fname, fsize|
      File.should_receive(:size).any_number_of_times.with(fname).and_return(fsize)
    end
    @packer = OJS::Packer.new(@reqs)
    @packs = @packer.packs
  end
  def test_packs_for_page(page)
    @reqs[page].each do |req|
      @packer.packs_for(page).flatten.should include(req)
    end
  end
  it "should properly combine page packs" do
    @packs[5..6].should eql(@packer.page_packs)
  end
  it "should properly combine sub packs" do
    @packs[1..4].should eql(@packer.sub_packs)
  end
  it "should properly combine the common pack" do
    @packs[0].should eql(@packer.common_pack)
  end
  it "should create a page pack for torrent_edit and discussion_edit" do
    @packer.page_packs.should eql([["torrent_edit.js"], ["discussion_edit.js"]])
  end
  it "should create sub packs with (suggestion + comments), discussions, listings and torrent" do
    @packer.sub_packs.should eql([["suggestion.js", "sug_support.js", "comments.js"], ["discussion.js"], ["listings.js"], ["torrent.js"]])
  end
  it "should create a common pack" do
    @packer.common_pack.should eql(["prototype.js", "scriptaculous.js", "class.js", "event_dispatcher.js", "login.js"])
  end
  it "should determine the aprioriate packs for torrent/edit" do
    test_packs_for_page("torrent/edit"     )
  end
  it "should determine the aprioriate packs for discussion/list" do
    test_packs_for_page("discussion/list"  )
  end
  it "should determine the aprioriate packs for discussion/edit" do
    test_packs_for_page("discussion/edit"  )
  end
  it "should determine the aprioriate packs for torrent/show" do
    test_packs_for_page("torrent/show"     )
  end
  it "should determine the aprioriate packs for torrent/list" do
    test_packs_for_page("torrent/list"     )
  end
  it "should determine the aprioriate packs for discussion/show" do
    test_packs_for_page("discussion/show"  )
  end
end

describe OJS::Packer, "with archtypical requirements" do
  before(:each) do
    @reqs = {
      "A" => [1,2, 3,4, 10,11 ],
      "B" => [1,2, 3,4, 12,13 ],
      "C" => [1,2, 5,6, 14,15 ],
      "D" => [1,2, 5,6, 16,17 ]
    }
    File.stub!(:size).and_return(1)
    @packer = OJS::Packer.new(@reqs)
  end
  it "should return the proper common packs" do
    @packer.common_pack.should eql([1,2])
  end
  it "should return the proper sub packs"  do
    @packer.sub_packs.should eql([[3,4], [5,6]])
  end
  it "should return the proper page packs"  do
    @packer.page_packs.should eql([[10, 11], [12, 13], [14, 15], [16, 17]])
  end
end
