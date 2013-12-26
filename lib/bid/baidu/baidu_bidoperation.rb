require "awesome_print"
require "db"
require "baidu"
# require "json"
require "pz"
require "date"

module BidService
	module BaiduPC
		#define bid operations for BaiduPC.
		class BaiduBidoperation
			# include Db

			def initialize
				@productId = 1
				@auth = Baidu::Auth.new
				@exactConfig = Db::EnvConfig.new('baidu','hotel','exact')
				@phraseConfig = Db::EnvConfig.new('baidu','hotel','phrase')

				# Ranking Variables
				@pzClient = Pz.new("PC")
				@domain = 'elong.com'
			end

			#get bid tasks from bid_queue
			def getBidJob(num = 5)
				params = {:productId => @productId, :enabled => 1}
				# ap params
				return Db::VBidJobinfo.where("ProductId = ? AND Enabled = ? AND FetchGuid IS NULL AND RunTime <= NOW()", 
					params[:productId], params[:enabled]).order("RunTime ASC, BidStatus DESC").limit(num)
			end

			# get Keyword List by KeywordGroupId and MatchType
			def getKeywordsByKeywordGroupId(keywordGroupId, bidMatchType)
				keywords = []
				# bidMatchType: 7 - exact & phrase | 1 - exact only | 2 - phrase only
				case bidMatchType
				  when 1
				  	keywords = Db::VBidDetail.config(@exactConfig).where("keyword_group_id = ?", keywordGroupId)
				  when 2 
				  	keywords = Db::VBidDetail.config(@phraseConfig).where("keyword_group_id = ?", keywordGroupId)				  	
				  when 7
				  	exactKeywords = Db::VBidDetail.config(@exactConfig).where("keyword_group_id = ?", keywordGroupId)
				  	unless exactKeywords.nil?
				  		exactKeywords.each do |keyword|
				  			keywords << keyword
				  		end
				  	end
				  	# --------
				  	phraseKeywords = Db::VBidDetail.config(@phraseConfig).where("keyword_group_id = ?", keywordGroupId)	  	
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
			    	if result["result"][0]["taskStatus"] == "COMPLETE"
			    		return result
			    	end
			    end
			    @pzClient.del(taskIds)
				end
				return {}
			end # end of getPZRanking

			# get PositionInfo from rankingResult
			def getPositionInfo_PZ(rankingResult)
				unless rankingResult.empty?
					rr = rankingResult["result"][0]
					# ap rr
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

			def bid(bidJob, keywordDetail, currentPositionInfo, specialStrategy)
				# initialize bid strategy
				if specialStrategy.nil?
					strategy = {
						:targetSide => bidJob.DefaultTargetSide,
						:targetPosition => bidJob.DefaultTargetPosition,
						:timespan => bidJob.DefaultTimeSpan
					}
				else
					strategy = {
						:targetSide => specialStrategy.targetSide,
						:targetPosition => specialStrategy.targetPosition,
						:timespan => specialStrategy.TimeSpan
					}
				end

				bidResult = checkBiddingResult(currentPositionInfo, strategy)
				# ap bidResult
				# ap bidJob.BidStatus

				if bidResult <= 0
					# get target, then try to decrease price
					priceNew = priceDecrease(bidJob, keywordDetail, bidResult)
					bidJob.BidStatus = 2
				elsif bidResult > 0 && (bidJob.BidStatus == 0 || bidJob.BidStatus == 1)
					# ap 'priceIncrease'
					priceNew = priceIncrease(bidJob, keywordDetail, bidResult)
					bidJob.BidStatus = 1
				elsif bidResult > 0 && bidJob.BidStatus == 2
					priceNew = priceRecover(bidJob, keywordDetail)
					bidJob.BidStatus = 0
				end
				ap "priceNew=#{priceNew}"
				ap "BidStatus = #{bidJob.BidStatus}"

				# update baidu price with api
				keywordDetail.each do |keyword|
					price = priceNew[:priceExact] if keyword.match_type == 1
					price = priceNew[:pricePhrase] if keyword.match_type == 2
					keywordType = {:keywordId=> keyword.keyword_se_id,:price => price}
					@auth.username = keyword.account_name
					@auth.password = keyword.password
					@auth.token = keyword.api_key
					baiduApiClient = Baidu::SEM::KeywordService.new(@auth)
					res = baiduApiClient.updateKeyword({:keywordTypes=>[keywordType]})
					ap res
					if res.status == 0
						# save price to keyword
						kw = Db::Keyword.config(@exactConfig).where("se_id = ?", keyword.keyword_se_id).take if keyword.match_type == 1
						kw = Db::Keyword.config(@phraseConfig).where("se_id = ?", keyword.keyword_se_id).take if keyword.match_type == 2
						kw.price = price
						kw.save
					end
				end
				# save bid_words
				bidword = Db::BidWord.where("BidWordId = ?", bidJob.BidWordId).take
				bidword.CurrentPrice = priceNew[:priceExact]
				bidword.CurrentSide = currentPositionInfo[:rankingSide]
				bidword.CurrentPosition = currentPositionInfo[:rankingPosition]
				bidword.Updated = DateTime.now
				bidword.save

				newBidJob = {
					:RunTime => DateTime.now.advance(:minutes => strategy[:timespan]),
					:BidWordId => bidJob.BidWordId,
					:BidStatus => bidJob.BidStatus,
					:JobInfo => {
						:rankingSide => currentPositionInfo[:rankingSide],
						:rankingPosition => currentPositionInfo[:rankingPosition],
						:priceExact => priceNew[:priceExact],
						:pricePhrase => priceNew[:pricePhrase],
						:bidTime => DateTime.now
					}
				}
				return newBidJob
			end

			# increase price for specified bidword with bidWordDetail.
			def priceIncrease(jobInfo, bidWordDetail, bidResult)
				currentPrice = jobInfo.CurrentPrice
				limitCPC = jobInfo.LimitCPC
				# use different algorithms according to bidResult
				if bidResult == 1
					priceExact = (limitCPC - currentPrice) / 3 + currentPrice
				elsif bidResult > 1
					priceExact = (limitCPC - currentPrice) / 2 + currentPrice
				end
				priceExact = limitCPC if priceExact > limitCPC
				pricePhrase = format("%.2f",priceExact/3).to_f
				return {:priceExact => priceExact, :pricePhrase => pricePhrase}
			end

			# decrease price for specified bidword with bidWordDetail.
			def priceDecrease(jobInfo, bidWordDetail, bidResult)
				currentPrice = jobInfo.CurrentPrice
				minCPC = jobInfo.MinCPC
				priceExact = currentPrice - (currentPrice - minCPC) / 3
				priceExact = minCPC if priceExact < minCPC
				pricePhrase = format("%.2f",priceExact/3).to_f
				pricePhrase = minCPC if pricePhrase < minCPC
				return {:priceExact => priceExact, :pricePhrase => pricePhrase}
			end

			# Recover price to previous price TODO
			def priceRecover(jobInfo, bidWordDetail)
			end

			# check bidding result(<=0 get | >0 unreached | <-9 none ranking)
			def checkBiddingResult(currentPositionInfo, bidStrategy)
				if currentPositionInfo[:rankingSide] > 0 && currentPositionInfo[:rankingPosition] > 0
					currentPositionIndex = (currentPositionInfo[:rankingSide] - 1)*8 + currentPositionInfo[:rankingPosition]
					targetPositionIndex = (bidStrategy[:targetSide] - 1)*8 + bidStrategy[:targetPosition]
					return currentPositionIndex - targetPositionIndex
				else
					return 10 # ranking result is none
				end
			end

		end
	end
end