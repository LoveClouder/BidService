require "awesome_print"
# ap File.expand_path()
# ap File.read(File.expand_path)
require "db"


module BidService
	module Baidu
		#define bid operations for BaiduPC.
		class BaiduBidoperation
			include Db

			def test
				ap BidWord.take.to_json
			end
		end
	end
end