require "awesome_print"
# ap File.expand_path()
# ap File.read(File.expand_path)
require "db"


module BidService
	module Baidu
		#define bid operations for BaiduPC.
		class BaiduBidoperation
			include Db

			def initialize
				@productId = 1
			end

			#get bid tasks from bid_queue
			def getBidJob(num = 5)
				params = {:productId => @productId, :enabled => 1}
				# ap params
				return VBidJobinfo.where("ProductId = ? AND Enabled = ? AND FetchGuid IS NULL AND RunTime <= NOW()", 
					params[:productId], params[:enabled]).order("RunTime ASC, BidStatus DESC").limit(num)
			end

			def getKeywordsByKeywordGroupId(keywordGroupId, bidMatchType)
				keywords = []
				exactConfig = EnvConfig.new('baidu','hotel','exact')
				phraseConfig = EnvConfig.new('baidu','hotel','phrase')
				# vBidDetailExact = VBidDetail.config(exactConfig)
				# vBidDetailphrase = VBidDetail.config(phraseConfig)
				# bidMatchType: 7 - exact & phrase | 1 - exact only | 2 - phrase only
				case bidMatchType
				  when 1
				  	keywords = VBidDetail.config(exactConfig).where("keyword_group_id = ?", keywordGroupId)
				  when 2 
				  	keywords = VBidDetail.config(phraseConfig).where("keyword_group_id = ?", keywordGroupId)				  	
				  when 7
				  	exactKeywords = VBidDetail.config(exactConfig).where("keyword_group_id = ?", keywordGroupId) 
				  	phraseKeywords = VBidDetail.config(phraseConfig).where("keyword_group_id = ?", keywordGroupId)
				  	#
				  	unless exactKeywords.nil?
				  		exactKeywords.each do |keyword|
				  			keywords << keyword
				  		end
				  	end
				  	unless phraseKeywords.nil?
				  		phraseKeywords.each do |keyword|
				  			keywords << keyword
				  		end
				  	end
				end
				return keywords
			end

		end
	end
end

BidService::Baidu::BaiduBidoperation.new.getKeywordsByKeywordGroupId(1034, 1)