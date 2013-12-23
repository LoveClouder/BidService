require "awesome_print"
require "db"
# require "json"
require "pz"


module BidService
	module Baidu
		#define bid operations for BaiduPC.
		class BaiduBidoperation
			include Db

			def initialize
				@productId = 1

				# Ranking Variables
				@pzClient = Pz.new("PC")
				@domain = 'elong.com'
			end

			#get bid tasks from bid_queue
			def getBidJob(num = 5)
				params = {:productId => @productId, :enabled => 1}
				# ap params
				return VBidJobinfo.where("ProductId = ? AND Enabled = ? AND FetchGuid IS NULL AND RunTime <= NOW()", 
					params[:productId], params[:enabled]).order("RunTime ASC, BidStatus DESC").limit(num)
			end

			# get Keyword List by KeywordGroupId and MatchType
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
				  	unless exactKeywords.nil?
				  		exactKeywords.each do |keyword|
				  			keywords << keyword
				  		end
				  	end
				  	# --------
				  	phraseKeywords = VBidDetail.config(phraseConfig).where("keyword_group_id = ?", keywordGroupId)	  	
				  	unless phraseKeywords.nil?
				  		phraseKeywords.each do |keyword|
				  			keywords << keyword
				  		end
				  	end
				end
				return keywords
			end

			# get ranking by pz api(single word)
			def getPZRanking(keyword)
				result = {}
				unless keyword.nil?
					# initialize keyworddetail
					rankingKeyword = {
			      "customerId"=> keyword.account_se_id,
			      "campaignId"=> keyword.campaign_se_id,
			      "adGroupId"=> keyword.adgroup_se_id,
			      "keywordId"=> keyword.keyword_se_id,
			      "keywordText"=> keyword.keyword_string,
			      "deviceType"=> "PC",
			      "priority"=> "REALTIME",
			      "network"=> "BAIDU",
			      "keywordMatchType"=> keyword.match_type,
			      "qualityInfo"=> keyword.qc,
			      "keywordBid"=> keyword.price,
			      "displayUrls"=> [],
			      "openDomains"=> [
			       "elong.com"
			     ],
			      "regionCode"=> "1000",
			      "taskId"=> nil
			    }
			    rankingKeywords = []
			    rankingKeywords << rankingKeyword
			    taskIds = @pzClient.add(rankingKeywords)

			    # try 3 times
			    (1..3).each do |num|
			    	sleep 2
			    	result = @pzClient.get(taskIds)
			    	# ap result
			    	break if result["result"][0]["taskStatus"] == "COMPLETE"
			    end
			    @pzClient.del(taskIds)
				end
				return result
			end # end of getPZRanking

			# get PositionInfo from rankingResult
			def getPositionInfo_PZ(rankingResult)
				unless rankingResult.empty?
					rr = rankingResult["result"][0]
					# topAds
					if rr["topAds"].count > 0
						rr["topAds"].each do |ad|
							if ad["adType"] == "TEXT_AD" && (ad["displayUrl"].include? @domain)
 								positionInfo = {
									:rankingSide => 1,	# left side
									:rankingPosition => ad["position"]
								}
								return positionInfo
							end
						end
					end
					# inlineAds
					if rr["inlineAds"].count > 0
						rr["inlineAds"].each do |ad|
							if ad["adType"] == "TEXT_AD" && (ad["displayUrl"].include? @domain)
 								positionInfo = {
									:rankingSide => 1,	# left side
									:rankingPosition => ad["position"]
								}
								return positionInfo
							end
						end
					end
					# rightAds
					if rr["rightAds"].count > 0
						rr["rightAds"].each do |ad|
							if ad["adType"] == "TEXT_AD" && (ad["displayUrl"].include? @domain)
 								positionInfo = {
									:rankingSide => 1,	# left side
									:rankingPosition => ad["position"]
								}
								return positionInfo
							end
						end
					end
					# ----------------------------------
				end
				return {
					:rankingSide => 0,	# none side
					:rankingPosition => -1 	# none position
				}
			end # end of getPositionInfo_PZ

		end
	end
end