require 'set'
module OJS
  module Loader
    # Given a hash of requirements for a set of pages (i.e. {"page A"=>["req1.js", "req2.js"], "page B" => [...]} ) will generate 
    # a list of "packages" which will limit the required number of files per page to 3 and heuristically minimize needless re-download.
    # 
    # For example, given requirements:
    #   A => [1,2, 3,4, 10,11]
    #   B => [1,2, 3,4, 12,13]
    #   C => [1,2, 5,6, 14,15]
    #   D => [1,2, 5,6, 16,17]
    #
    # A package of common files (common_pack) is detected first:
    #   Pack 0: [1,2]
    # Then sub packages are detected that are neither universal nor unique accross pages:
    #   Pack 1: [3,4]
    #   Pack 2: [5,6]
    # Finally, left over unique files are put into per-page packages (sub_packs):
    #   Pack 3: [10,11]
    #   Pack 4: [12,13]
    #   Pack 5: [14,15]
    #   Pack 6: [15,17]
    # (Use Packer#packs to get this array of packages)
    # 
    # Now per-page requests can be minimized by having each page load no more thern 3 packs (page_packs):
    #   A => Packs 0,1,3
    #   B => Packs 0,1,4
    #   C => Packs 0,2,5
    #   D => Packs 0,2,6
    # (Use Packer#packs_for(page) to get the packs directly)
    #
    # The generated packages are _not_ provably optimal, but the heuristics should hold up to most day-to-day cases.
    class Packer
      # Creates a packer for the set of requirements expressed in the hash.
      # Options:
      #  all_threshold:          portion of pages a req must be present in to be included in the common pack (default = 0.7)
      #  association_threshold:  correlation coefficient between sub_pack starter and candidates required for inclusion into the same pack as the starter (default = 0.5)
      def initialize(page_requirements, options={})
        @options = ({:limit=>3, :all_threshold=>0.7, :association_threshold=>0.5}).merge(options)
        @page_requirements = page_requirements
      end
      attr_reader :options
      # Returns the full list of optimized packages for the given requirements
      def packs
        packs = []
        packs += [common_pack] unless common_pack.empty?
        packs += sub_packs unless sub_packs.empty?
        packs += page_packs unless page_packs.empty?
        packs
      end
      # Generates a package out of req files that are needed for options[:all_threshold] % of pages.
      def common_pack
        file_counts = all_resources.counts
        Package.new(unique_resources.select{|f| file_counts[f] > (@page_requirements.keys.size * options[:all_threshold])})
      end
      # Calculates sub-packages. Those files with the highest potential to waste bandwith (req occurance * req size) are selected first
      # as candidates for a new package (given they occur more then once). Then any subgroups that include them are identified (options[:association_threshold]
      # of 1.0 would ensure a strict correlation, lower values allow looser correlation to suffice for inclusion) and added to a pack.
      def sub_packs
        find_best_sub_pack_in(page_resources_without_common_pack)
      end
      # Identifies any left over packages that will remain unique per-page.
      def page_packs
        page_resources_without_common_pack.collect{|reqs| Package.new(sub_packs.inject(reqs){|req_pack, sub_pack| req_pack - sub_pack.resources}) }.reject{|p| p.empty?}
      end
      # Return an array of packs containing the files neccessary for a pack 
      def packs_for(page)
        resort_packs(@page_requirements[page].inject(Set.new){|page_packs, page_req|
          best_pack = packs.find_all{|pack| pack.include?(page_req)}.max_by {|pack| (pack & @page_requirements[page]).size}
          page_packs.add(best_pack)
        }.to_a)
      end
      private 
      # Ensure common pack goes first, then sub pack, then page pack
      def resort_packs(packs_for_page)
        sorted_packs = []
        sorted_packs << common_pack
        sorted_packs << (sub_packs & packs_for_page).first
        sorted_packs << (page_packs & packs_for_page).first
        sorted_packs.compact
      end
      def find_best_sub_pack_in(page_resources)
        freq_counts = page_resources.flatten.counts
        largest_waste_of_bandwith = page_resources.flatten.uniq.reject{|r| freq_counts[r] < 2}.max_by{|r| r.size * freq_counts[r]}
        pages_that_contain_the_bandwith_waster = page_resources.find_all{|o| o.include?(largest_waste_of_bandwith)}
        associated_counts = pages_that_contain_the_bandwith_waster.flatten.counts
        #Find resources that show up with the bandwith waster more then a #{association_threshold} amount of times (as a percentage relative to page counts)
        new_pack = pages_that_contain_the_bandwith_waster.flatten.uniq.find_all do |o|
          associated_counts[o] > (options[:association_threshold] * pages_that_contain_the_bandwith_waster.size)
        end
        if new_pack.empty? then return [] end
        [Package.new(new_pack)] +  find_best_sub_pack_in(page_resources.collect{|o| o - new_pack}.reject{|o| o.empty?})
      end
      def page_resources_without_common_pack
        @page_requirements.values.collect{|reqs| reqs - common_pack.resources}
      end
      def all_resources
        @page_requirements.values.flatten
      end
      def unique_resources
        all_resources.uniq
      end
      cache_method :packs,  :unique_resources, :common_pack, :all_resources, :page_resources_without_common_pack, :packs_for, :page_packs, :sub_packs
    end
  end
end
