#!/usr/bin/env ruby
require 'pry'
require 'net/http'
require 'cgi'
require 'uri'
require 'base64'
require 'json'
require 'date'

class JsonWebApi
  def self.set_header(header_hash)
    @@header_hash = header_hash
  end
  def self.get_header
    @@header_hash
  end
  def self.request(url, req)
    uri = URI.parse(url)
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true
    sleep 1
    response = https.request(req)
    unless response.code.to_s == '200'
      raise "response error: #{response.code.to_s}} => #{response.body}"
    end
    return JSON.parse(response.body)
  end
  def self.get(uri)
    @@header_hash ||= {}
    req = Net::HTTP::Get.new(uri, @@header_hash)
    yield req
    return self.request(uri, req)
  end
  def self.post(uri)
    @@header_hash ||= {}
    req = Net::HTTP::Post.new(uri, @@header_hash)
    yield req
    return self.request(uri, req)
  end
end

class ZendeskParser
  def initialize(subdomain, email, access_token)
    @subdomain = subdomain
    @email = email
    @access_token = access_token
  end

  def pagenate(uri, aggregate_array, aggregate_key = 'results')
    response = JsonWebApi.get(uri) do |req|
      req.basic_auth("#{@email}/token", @access_token)
    end
    aggregate_array = aggregate_array + response[aggregate_key]
    print "#{aggregate_array.count}/#{response['count']}\n"
    if response['next_page']
      aggregate_array = pagenate(response['next_page'], aggregate_array, aggregate_key)
    end
    aggregate_array
  end

  def search(query)
    query = CGI.escape(query)
    uri = "https://#{@subdomain}.zendesk.com/api/v2/search.json?query=#{query}"
    results = []
    results = pagenate(uri, results, 'results')
    results
  end

  def users_from_search(json_tickets)
    user_links = json_tickets.map do |result|
      media_id = nil
      /admin\/users\/(\d+)/.match(result['notes']) do |m|
        media_id = m[1]
      end
      media_id
    end.uniq.compact
  end
end

if __FILE__ == $0
  token = ENV['ZENDESK_ACCESS_TOKEN']
  subdomain = ENV['ZENDESK_SUBDOMAIN']
  email = ENV['ZENDESK_EMAIL']
  raise 'ZendeskのAPI Tokenを、環境変数 ZENDESK_ACCESS_TOKEN にセットしてください' unless token
  raise 'Zendeskのsubdomainを、環境変数 ZENDESK_SUBDOMAIN にセットしてください' unless subdomain
  raise 'Zendeskの email を、環境変数 ZENDESK_EMAIL にセットしてください' unless email
  
  z = ZendeskParser.new(subdomain, email, token)
  search_query = 'notes:"admin/users"'
  if ARGV[0]
    search_query = "#{search_query} #{ARGV[0]}"
  else
    interval = (Date.today - 3).strftime("%Y-%m-%d")
    search_query = "#{search_query} created>#{interval}"
  end

  tickets = z.search(search_query)
  users = z.users_from_search(tickets)

  print users.sort.join(',')
  print "\n"
end