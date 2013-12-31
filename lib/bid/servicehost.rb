require "./bidoperation"
require "./log"
# require "Date"


module BidService
	class Servicehost

		def initialize(productId = 1)
			@operations = Bidoperation.new(productId)
		end

		def onStart(pollingInterval = 6,jobNum = 1)
			$Logger.debug("0. BidService start...")
			loop do
				$Logger.debug("1. Entering bidding loop...")
				#bid progress
				bidJobs = @operations.getBidJobInfo(jobNum)
				unless bidJobs.nil?
					bidJobs.each do |job|
						begin
							# get keywords by natural word
							keywords = @operations.getKeywordsByKeywordGroupId(job.KeywordGroupId, job.BidMatchType)
							if keywords.nil?
								raise "Word #{job.WordString} has no keywords."	# EXIT 1
							end
							# get ranking with pz api
							if keywords.select{|i| i.match_type == 1}.count >= 1
								# ap keywords.select{|i| i.match_type == 1}
								rankingKeyword = keywords.select{|i| i.match_type == 1}[0]
							else
								rankingKeyword = keywords.select{|i| i.match_type == 2}[0]
							end
							rankingResult = @operations.getPZRanking(rankingKeyword)
							ap rankingResult
							if rankingResult.empty?
								raise "Word #{job.WordString} rankingresult is nil. This may be caused by network error, timeout or other errors."
							end
							# get position info
							currentPosition = @operations.getPositionInfo_PZ(rankingResult)
							ap currentPosition

							# get bidword strategy
							bidSpecialStrategy = @operations.getBidWordSpecialStrategy(job)

							# bid core logistics
							bidResultInfo = @operations.bid(job, keywords, currentPosition, bidSpecialStrategy)

							# generate nextJobInfo
							@operations.saveNewJob(bidResultInfo)

						rescue Exception => e
							$Logger.error(e.message)
							bidResultInfo = {
								:RunTime => DateTime.now.advance(:minutes => 1),
								:BidWordId => job.BidWordId,
								:BidStatus => job.BidStatus,
								:JobInfo => {
									:rankingSide => job.CurrentSide,
									:rankingPosition => job.CurrentPosition,
									:priceExact => job.CurrentPrice,
									:pricePhrase => format("%.2f", job.CurrentPrice/3).to_f,
									:bidTime => DateTime.now
								}
							}
							@operations.saveNewJob(bidResultInfo)
							next
						end
					end
				end

				$Logger.debug("Exit bidding loop...waiting next bidding.")
				# 如果一次获取多个任务，可以取消轮询等待时间(改时间主要是为了让出价对排名的影响生效)
				sleep(pollingInterval)
			end

		end

	end
end

BidService::Servicehost.new(1).onStart()