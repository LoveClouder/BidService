require "./baidu/baidu_bidoperation"

module BidService
	#Define base operations in bidding progress.
	class Bidoperation

		def initialize(searchProductId)
			#initialize instance according to searchProductId.
			case searchProductId
			when 1
				@bidoperation = BaiduPC::BaiduBidoperation.new
			end
		end

		# def test
		# 	@bidoperation.test
		# end

		# get bid task from bid_queue
		def getBidJobInfo(num)
			return @bidoperation.getBidJob(num)
		end

		# get Keyword List by KeywordGroupId and MatchType
		def getKeywordsByKeywordGroupId(keywordGroupId, bidMatchType)
			return @bidoperation.getKeywordsByKeywordGroupId(keywordGroupId, bidMatchType)
		end

		# get pagerank result for specified keyword
		def getPZRanking(keyword)
			return @bidoperation.getPZRanking(keyword)
		end

		# get PositionInfo from rankingResult
		def getPositionInfo_PZ(rankingResult)
			return @bidoperation.getPositionInfo_PZ(rankingResult)
		end

		def getBidWordSpecialStrategy(job)
			return @bidoperation.getBidWordSpecialStrategy(job)
		end

		def bid(bidJob, keywordDetail, currentPositionInfo, specialStrategy = nil)
			return @bidoperation.bid(bidJob, keywordDetail, currentPositionInfo, specialStrategy)
		end

		def saveNewJob(bidResultInfo)
			return @bidoperation.saveNewJob(bidResultInfo)
		end

	end
end

# BidService::Bidoperation.new(1).getBidJob(5)