require "./bidoperation"
# require "Date"

module BidService
	class Servicehost

		def initialize(productId = 1)
			@host = Bidoperation.new(productId)
		end

		def onStart(pollingInterval = 10,jobNum = 1)

			loop do
				# p 'bidding...'
				#bid progress

				


				# 如果一次获取多个任务，可以取消轮询等待时间(改时间主要是为了让出价对排名的影响生效)
				sleep(pollingInterval)
			end

		end

	end
end

BidService::Servicehost.new.onStart()
