require "./baidu/baidu_bidoperation"

module BidService
	#Define base operations in bidding progress.
	class Bidoperation

		def initialize(searchProductId)
			#initialize instance according to searchProductId.
			case searchProductId
			when 1
				@bidoperation = Baidu::BaiduBidoperation.new
			end
		end

		# def test
		# 	@bidoperation.test
		# end

		#get bid task from bid_queue
		def getBidJob(num)

		end

		#get pagerank result for specified keyword,specified search engine.
		def getRanking(keyword,searchProductId)
		end

		#increase price for specified bidword with bidWordDetail.
		def priceIncrease(bidWordDetail)
		end

		#decrease price for specified bidword with bidWordDetail.
		def priceDecrease(bidWordDetail)
		end

		#check bidding result(Model:RankingResult)
		def checkBiddingResult(currentRanking, targetRanking)
		end

	end
end

# BidService::Bidoperation.new(1).test