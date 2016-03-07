# This file is used by Rack-based servers to start the application.
require 'rubygems'
require 'sinatra'
require './scountaf.rb' # 也就是你的sinatra app檔名

FileUtils.mkdir_p 'log' unless File.exists?('log')
log = File.new("log/sinatra.log", "a")
$stderr.reopen(log)

use Rack::ShowExceptions
use Rack::ContentLength

run Sinatra::Application


