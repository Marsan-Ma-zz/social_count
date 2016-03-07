# coding: utf-8
require 'sinatra'
require 'sinatra/contrib/all'
require 'json'
#require 'thin'
require './lib/social_count.rb'

set :server, %w[webrick mongrel thin]

helpers do
  def partial (template, locals = {})
    erb(template, :layout => false, :locals => locals)
  end
end

configure :development do
  ENV["SINA_ENV"] = "dev"
end

#====================================
#   Test
#====================================
get '/' do
  erb :index
end

#====================================
#   SCount
#====================================
post '/api/launch' do
  raw = JSON.parse(request.body.read)
  stamp = raw['stamp']
  # p "[STAMP]" + stamp.to_s
  if (!stamp.nil? && (stamp > 0))
    SocialCount.new.get_social_count(raw, true)
    # jsonp response
    callback = params.delete('callback')
    resp = {'status' => 'ok'}.to_json
  else
    resp = {'status' => 'thanks'}.to_json
  end
  # content_type :js
  # resp = "#{callback}#{CNTS.to_json}" ###
end

post '/api/fag' do
  raw = JSON.parse(request.body.read)
  stamp = raw['stamp'].to_i
  # p raw
  if (!stamp.nil? && (stamp > 0))
    SocialCount.new.fql_agent(raw)
    # jsonp response
    callback = params.delete('callback')
    resp = {'status' => 'ok'}.to_json
  else
    resp = {'status' => 'thanks'}.to_json
  end
end

get '/api/wait' do
  resp = {'status' => SocialCount.working}.to_json
end 

get '/api/result' do
  result = SocialCount.cnts.to_json
  SocialCount.reset
  result
end

