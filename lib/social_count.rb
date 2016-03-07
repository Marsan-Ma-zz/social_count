# encoding: utf-8
require 'fql'
require 'em-http-request'

class SocialCount

  PATH_FACEBOOK = 'http://api.ak.facebook.com/restserver.php?v=1.0&method=links.getStats&format=json&urls='
  PATH_GPLUS = 'https://clients6.google.com/rpc?key=AIzaSyCKSbrvQasunBoV16zDH9R33D88CeLr9gQ'
  PATH_TWITTER = 'http://cdn.api.twitter.com/1/urls/count.json?url='
  PATH_PINTER = 'http://api.pinterest.com/v1/urls/count.json?url='
  PATH_REDDIT = 'http://buttons.reddit.com/button_info.json?url='
  PATH_DELICIOUS = 'http://feeds.delicious.com/v2/json/urlinfo/data?url='
  PATH_LINKEDIN = 'http://www.linkedin.com/countserv/count/share?format=json&url='
  PATH_STUMBLE = 'http://www.stumbleupon.com/services/1.01/badge.getinfo?url='
  PATH_GTREND = 'http://www.google.com/trends/fetchComponent'
  FQL_PREFIX = 'SELECT url, total_count from link_stat where url IN '

  SOCIALS = [
    # ["facebook", PATH_FACEBOOK], 
    ["twitter", PATH_TWITTER] #, ["pinter", PATH_PINTER],
    # ["delic", PATH_DELICIOUS], ["linkedin", PATH_LINKEDIN], ["reddit", PATH_REDDIT], 
    # ["stumble", PATH_STUMBLE]
  ]

  # As global variable
  @@working = false
  @@cnts = Hash.new(0)

  def self.working
    @@working
  end

  def self.cnts
    @@cnts
  end

  def self.reset
    @@working = false
    @@cnts = Hash.new(0)
  end

  #============================================
  #   1. Get Social Network Counts
  #============================================
  def fql_agent(raw)
    fql_hash = Hash.new
    offset = 0
    fql = nil
    @@working = true
    @@cnts['stamp'] = raw['stamp']
    begin
      fql = Fql.execute(raw['command'])
    rescue
      fb_trycnt += 1  # "FQL error, maybe quota limit." if debug
      if (fb_trycnt < 3)
        sleep 30  # prevent quota limit
        retry
      end
    end
    @@cnts['result'] = fql
    @@working = false
    return true
  end

  # SocialCount.new.get_social_count(urls)
  def get_social_count(raw, debug=false, do_fb=false)
    # parse input
    @@working = true
    @@cnts['stamp'] = raw['stamp']
    raw.delete('stamp')
    urls = raw.values
    if (urls.count == 0)
      @@working = false
      return true
    end
    # p "[CNTS START]" + urls.count.to_s
    # p @@cnts
    # Facebook FQL
    if do_fb
      fql_hash = Hash.new
      offset = 0
      urls.in_groups_of(300, false) do |batch|
        fb_trycnt = 0
        begin
          fql = Fql.execute(FQL_PREFIX + "(" + batch.map{|u| CGI::escape(u)}.to_s[1..-2] + ")")
        rescue
          fb_trycnt += 1  # "FQL error, maybe quota limit." if debug
          if (fb_trycnt < 5)
            sleep 30  # prevent quota limit
            retry
          end
        end
        if not fql.empty?
          fql.each{|f| fql_hash[CGI::unescape(f['url'])] = f['total_count']}
          urls.each_with_index do |u, idx| 
            val = fql_hash[urls[idx]]
            @@cnts["facebook_#{idx+offset}"] = fql_hash[urls[idx]]
          end
        end
        offset += 300
      end
      # return cnts
    end
    # p "[CNTS AFTER FB]" 
    # p @@cnts
    # others
    offset = 0
    urls.in_groups_of(300, false) do |batch|
      EM.run {
        multi = EventMachine::MultiRequest.new
        urls.each_with_index do |u, idx|
          eval %Q{
            multi.add "twitter_#{idx+offset}", EM::HttpRequest.new(PATH_TWITTER + CGI::escape(u), :connect_timeout => 5, :inactivity_timeout => 10).get
          }
          eval %Q{
            multi.add "gplus_#{idx+offset}", EM::HttpRequest.new(PATH_GPLUS, :connect_timeout => 5, :inactivity_timeout => 10).post(gplus_req(u))
          }
        end
        multi.callback do
          multi.responses[:callback].each do |sym, cb|
            @@cnts[sym] = json2count(sym.split('_')[0], cb.response)
          end
          multi.responses[:errback].each do |sym, cb|
            @@cnts[sym] = -1
          end
          # p "[CNTS FUNISHED]"
          # p @@cnts
          EM.stop
        end
      }
      offset += 300
    end
    @@working = false
    return true
  end


  #=================================
  #   Query
  #=================================
  

  #=================================
  #   Tasks
  #=================================
  private

  def json2count(source, resp)
    begin
      case source
      when "facebook"
        cnt = JSON.parse(resp)[0]['total_count'].to_i
      when "gplus"
        cnt = JSON.parse(resp)[0]['result']['metadata']['globalCounts']['count'].to_i
      when "delic"
        cnt = JSON.parse(resp)[0]['total_posts'].to_i
      when "linkedin"
        cnt = JSON.parse(resp)['count'].to_i
      when "pinter"
        cnt = JSON.parse(resp[13..-2])['count'].to_i
      when "reddit"
        cnt = JSON.parse(resp)['data']['children'][0]['data']['score'].to_i
      when "stumble"
        cnt = JSON.parse(resp)['result']['views'].to_i
      when "twitter"
        cnt = JSON.parse(resp)['count'].to_i
      end
    rescue
      cnt = nil
    end
    # p "#{source} - #{cnt}"
    return cnt
  end

  def gplus_req(url)
    payload = [{
      "method" => "pos.plusones.get",
      "id" => "p",
      "params" => {
        "nolog" => true,
        "id" => url,
        "source" => "widget",
        "userId" => "@viewer",
        "groupId" => "@self"
      },
      "jsonrpc" => "2.0",
      "key" => "p",
      "apiVersion" => "v1"
    }]
    
    request_options = {
      :body => payload.to_json,
      :head => {'Content-Type' =>'application/json'}
    }
    return request_options
  end

end
