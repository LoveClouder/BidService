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

			def getAdjustedSideAndPosition(side, position, adjustValue)
				newPosition = position + adjustValue
				if newPosition > 8
					if side == 1
						newSide = 2
						newPosition = newPosition - 8
					elsif side == 2
						newSide = 2
						newPosition = 8
					end
				elsif newPosition <= 8 && newPosition >= 1
					newSide = side
					newPosition = newPosition
				elsif newPosition < 1
					if side == 1
						newSide = 1
						newPosition = 1
					elsif side == 2
						newSide = 1
						newPosition = newPosition + 8
					end	
				end
				return {:newSide => newSide, :newPosition => newPosition}
			end

			def getBidWordSpecialStrategy(job)
				bidStrategy = Db::VBidStrategy.where("BidWordId = ?", job.BidWordId).take
				targetSide = bidStrategy.DefaultTargetSide
				targetPosition = bidStrategy.DefaultTargetPosition
				adjustedLimitCPC = job.LimitCPC
				timeSpan = bidStrategy.DefaultTimeSpan
				# 1. temp strategy by bidword
				unless (bidStrategy.TempPositionAdjustByBidWord).nil?
					adjustedPositionInfo = getAdjustedSideAndPosition(targetSide, targetPosition, bidStrategy.TempPositionAdjustByBidWord)
					targetSide = adjustedPositionInfo[:newSide]
					targetPosition = adjustedPositionInfo[:newPosition]
					timeSpan = bidStrategy.TempTimeSpanByBidWord
					adjustedLimitCPC = adjustedLimitCPC*(1 + bidStrategy.TempLimitCPCAdjustByBidWord)
					return {:targetSide => targetSide, :targetPosition => targetPosition, :timeSpan => timeSpan, :adjustedLimitCPC => adjustedLimitCPC}
				end
				# 2. temp strategy by bidwordgroup
				unless (bidStrategy.TempPositionAdjustByBidWordGroup).nil?
					adjustedPositionInfo = getAdjustedSideAndPosition(targetSide, targetPosition, bidStrategy.TempPositionAdjustByBidWordGroup)
					targetSide = adjustedPositionInfo[:newSide]
					targetPosition = adjustedPositionInfo[:newPosition]
					timeSpan = bidStrategy.TempTimeSpanByBidWordGroup
					adjustedLimitCPC = adjustedLimitCPC*(1 + bidStrategy.TempLimitCPCAdjustByBidWordGroup)
					return {:targetSide => targetSide, :targetPosition => targetPosition, :timeSpan => timeSpan, :adjustedLimitCPC => adjustedLimitCPC}
				end
				# 3. special strategy
				unless (bidStrategy.SpecialPositionAdjust).nil?
					adjustedPositionInfo = getAdjustedSideAndPosition(targetSide, targetPosition, bidStrategy.SpecialPositionAdjust)
					targetSide = adjustedPositionInfo[:newSide]
					targetPosition = adjustedPositionInfo[:newPosition]
					timeSpan = bidStrategy.SpecialTimeSpan
					adjustedLimitCPC = adjustedLimitCPC*(1 + bidStrategy.SpecialLimitCPCAdjust)
					return {:targetSide => targetSide, :targetPosition => targetPosition, :timeSpan => timeSpan, :adjustedLimitCPC => adjustedLimitCPC}
				end
				# 4. General strategy
				unless (bidStrategy.GeneralPositionAdjustByWeek).nil? || (bidStrategy.GeneralPositionAdjustByHour).nil?
					if (bidStrategy.GeneralPositionAdjustByHour).nil?
						adjustedPositionInfo = getAdjustedSideAndPosition(targetSide, targetPosition, bidStrategy.GeneralPositionAdjustByWeek)
						adjustedLimitCPC = adjustedLimitCPC*(1 + bidStrategy.GeneralLimitCPCAdjustByWeek)
					elsif (bidStrategy.GeneralPositionAdjustByWeek).nil?
						adjustedPositionInfo = getAdjustedSideAndPosition(targetSide, targetPosition, bidStrategy.GeneralPositionAdjustByHour)
						adjustedLimitCPC = adjustedLimitCPC*(1 + bidStrategy.GeneralLimitCPCAdjustByHour)
					else
						generalPositionAdjust = bidStrategy.GeneralPositionAdjustByWeek + bidStrategy.GeneralPositionAdjustByHour
						generalPositionAdjust = 1 if generalPositionAdjust > 0
						generalPositionAdjust = -1 if generalPositionAdjust < 0
						generalLimitCPCAdjust = (bidStrategy.GeneralLimitCPCAdjustByWeek + bidStrategy.GeneralLimitCPCAdjustByHour)/2

						adjustedPositionInfo = getAdjustedSideAndPosition(targetSide, targetPosition, generalPositionAdjust)
						adjustedLimitCPC = adjustedLimitCPC*(1 + generalLimitCPCAdjust)
					end
					targetSide = adjustedPositionInfo[:newSide]
					targetPosition = adjustedPositionInfo[:newPosition]
					return {:targetSide => targetSide, :targetPosition => targetPosition, :timeSpan => timeSpan, :adjustedLimitCPC => adjustedLimitCPC}
				end
				# special strategy is none
				return {}
			end

			# bid core logic
			def bid(bidJob, keywordDetail, currentPositionInfo, specialStrategy)
				# initialize bid strategy
				if specialStrategy.empty?
					strategy = {
						:targetSide => bidJob.DefaultTargetSide,
						:targetPosition => bidJob.DefaultTargetPosition,
						:timespan => bidJob.DefaultTimeSpan,
						:limitCPC => bidJob.LimitCPC
					}
				else
					strategy = {
						:targetSide => specialStrategy[:targetSide],
						:targetPosition => specialStrategy[:targetPosition],
						:timespan => specialStrategy[:timeSpan],
						:limitCPC => specialStrategy[:adjustedLimitCPC]
					}
				end

				bidResult = checkBiddingResult(currentPositionInfo, strategy)
				# ap bidResult
				# ap bidJob.BidStatus

				if bidResult <= 0
					# get target and previous status is try decrease price and CurrentPrice equals MinCPC
					# then finished bid progress
					if bidJob.BidStatus == 2 && bidJob.CurrentPrice == bidJob.MinCPC
						bidJob.BidStatus = 0
						priceNew = bidJob.MinCPC
					else
						# get target, then try to decrease price
						priceNew = priceDecrease(bidJob, keywordDetail, bidResult)
						bidJob.BidStatus = 2
					end
				elsif bidResult > 0 && (bidJob.BidStatus == 0 || bidJob.BidStatus == 1)
					if bidJob.BidStatus == 1 && bidJob.CurrentPrice == strategy[:limitCPC]
						# dont get target, but has reached the limit cpc, so get cheapest price for current position
						priceNew = getMinPriceAtCurrentPosition(bidJob, currentPositionInfo)
						bidJob.BidStatus = 0
					else
						# ap 'priceIncrease'
						priceNew = priceIncrease(bidJob, keywordDetail, bidResult, strategy)
						bidJob.BidStatus = 1
					end
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

				bidResultInfo = {
					:RunTime => DateTime.now.advance(:minutes => strategy[:timespan]),
					:BidWordId => bidJob.BidWordId,
					:BidStatus => bidJob.BidStatus,
					:JobInfo => {
						:rankingSide => currentPositionInfo[:rankingSide],
						:rankingPosition => currentPositionInfo[:rankingPosition],
						:priceExact => bidJob.CurrentPrice,
						:pricePhrase => format("%.2f", bidJob.CurrentPrice/3).to_f,
						:bidTime => DateTime.now
					}
				}
				return bidResultInfo
			end

			# increase price for specified bidword with bidWordDetail.
			def priceIncrease(jobInfo, bidWordDetail, bidResult, strategy)
				currentPrice = jobInfo.CurrentPrice
				limitCPC = strategy[:limitCPC]
				# use different algorithms according to bidResult
				if bidResult == 1
					priceExact = format("%.2f", ((limitCPC - currentPrice) / 3 + currentPrice)).to_f
				elsif bidResult > 1
					priceExact = format("%.2f", ((limitCPC - currentPrice) / 2 + currentPrice)).to_f
				end
				# min adjust range is 1
				priceExact = jobInfo.CurrentPrice + 1 if priceExact - jobInfo.CurrentPrice < 1

				priceExact = format("%.2f", limitCPC).to_f if priceExact > limitCPC
				pricePhrase = format("%.2f",priceExact/3).to_f
				return {:priceExact => priceExact, :pricePhrase => pricePhrase}
			end

			# decrease price for specified bidword with bidWordDetail.
			def priceDecrease(jobInfo, bidWordDetail, bidResult)
				currentPrice = jobInfo.CurrentPrice
				minCPC = jobInfo.MinCPC
				priceExact = format("%.2f", (currentPrice - (currentPrice - minCPC) / 3)).to_f
				# min adjust range is 0.5
				priceExact = jobInfo.CurrentPrice - 0.5 if jobInfo.CurrentPrice - priceExact < 0.5

				priceExact = format("%.2f", minCPC).to_f if priceExact < minCPC
				pricePhrase = format("%.2f",priceExact/3).to_f
				pricePhrase = format("%.2f", minCPC).to_f if pricePhrase < minCPC
				return {:priceExact => priceExact, :pricePhrase => pricePhrase}
			end

			# Recover price to previous price
			def priceRecover(jobInfo, bidWordDetail)
				lastedVaildRow = Db::BidQueuesHistory.where("BidWordId = ? and BidStatus <> ?", jobInfo.BidWordId, 2).order("BidQueueId DESC").first
				hashJobInfo = JSON[lastedVaildRow.JobInfo]
				priceExact = hashJobInfo["priceExact"]
				pricePhrase = hashJobInfo["pricePhrase"]
				return {:priceExact => priceExact, :pricePhrase => pricePhrase}
			end

			# get cheapest price for current position
			def getMinPriceAtCurrentPosition(jobInfo, currentPositionInfo)
				priceExact = jobInfo.CurrentPrice
				pricePhrase = format("%.2f",priceExact/3).to_f
				startPoint = Db::BidQueuesHistory.where("BidWordId = ? and BidStatus = ?", jobInfo.BidWordId, 0).order("BidQueueId DESC").first
				ap startPoint
				Db::BidQueuesHistory.where("BidWordId = ? and BidQueueId >= ?", jobInfo.BidWordId, startPoint.BidQueueId)
					.order("BidQueueId ASC").each do |hisJob|
						hashJobInfo = JSON[hisJob.JobInfo]
						# ap hashJobInfo
						if hashJobInfo["rankingSide"] == currentPositionInfo[:rankingSide] && hashJobInfo["rankingPosition"] == currentPositionInfo[:rankingPosition]
							priceExact = hashJobInfo["priceExact"]
							pricePhrase = hashJobInfo["pricePhrase"]
							break
						end
				end
				return {:priceExact => priceExact, :pricePhrase => pricePhrase}
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

			# save newJob and oldJob
			def saveNewJob(bidResultInfo)
				# save old job to BidQueueHis
				oldJob = Db::BidQueue.where("BidWordId = ?", bidResultInfo[:BidWordId]).take
				jobHis = Db::BidQueuesHistory.new
				unless oldJob.nil?
					jobHis.BidQueueId = oldJob.BidQueueId
				 	jobHis.RunTime = oldJob.RunTime
				 	jobHis.BidWordId = oldJob.BidWordId
				 	jobHis.BidStatus = oldJob.BidStatus
				 	jobHis.JobInfo = bidResultInfo[:JobInfo].to_json
				 	jobHis.Updated = oldJob.Updated
				 	jobHis.save
				 	oldJob.destroy
				end
				# save newJob to BidQueue
				newJob = Db::BidQueue.new
				newJob.RunTime = bidResultInfo[:RunTime]
				newJob.BidWordId = bidResultInfo[:BidWordId]
				newJob.BidStatus = bidResultInfo[:BidStatus]
				newJob.JobInfo = ""
				newJob.save
			end

		end
	end
end