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

			def getBidJob(num = 5)
				# BidQueue.order("RunTime DESC, BidStatus DESC").limit(num).each do |row|
				# 	# ap row
				# 	ap row.BidWordId
				# end
				# params = {:productId => @productId, :enabled => 1}
				# ap params
				return BidQueue.where("FetchGuid IS NULL").order("RunTime DESC, BidStatus DESC").limit(num)
			end



		end
	end
end

BidService::Baidu::BaiduBidoperation.new.getBidJob(5)