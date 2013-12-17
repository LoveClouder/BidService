require "./bidoperation"
# require "Date"

module BidService
	class Servicehost

		# def initialize
		# 	@trigger = 1
		# end

		def onStart(pollingInterval = 10,jobNum = 1)

			loop do
				#bid progress
				p 'bidding...'
				sleep(pollingInterval)
			end

		end

	end
end

BidService::Servicehost.new.onStart()
