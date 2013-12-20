require "logger"

# $Logger = Logger.new("../log/bid_service_" + (Time.now).strftime("%Y-%m-%d") + ".log", "daily")
$Logger = Logger.new(STDOUT)
$Logger.level = Logger::DEBUG
$Logger.datetime_format = "%Y-%m-%d %H:%M:%S"