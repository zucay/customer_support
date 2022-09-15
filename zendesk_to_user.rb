#!/usr/bin/env ruby
require 'pry'
require 'date'
require_relative 'json_web_api'

class ZendeskParser
  def initialize(subdomain, email, access_token)
    @subdomain = subdomain
    @email = email
    @access_token = access_token
  end

  def apicall(full_path_or_rel_path_with_params)
    if full_path_or_rel_path_with_params =~ /^http/
      uri = full_path_or_rel_path_with_params
    else
      uri = "https://#{@subdomain}.zendesk.com/api/v2/#{full_path_or_rel_path_with_params}"
    end

    JsonWebApi.get(uri) do |req|
      req.basic_auth("#{@email}/token", @access_token)
    end
  end

  def pagenate(path_with_params, aggregate_array, aggregate_key = 'results')
    response = apicall(path_with_params)
    aggregate_array = aggregate_array + response[aggregate_key]
    warn "#{aggregate_array.count}/#{response['count']}\n"
    if response['next_page']
      aggregate_array = pagenate(response['next_page'], aggregate_array, aggregate_key)
    end
    aggregate_array
  end

  def search(query)
    query = CGI.escape(query)
    rel_path = "search.json?query=#{query}"
    results = []
    results = pagenate(rel_path, results, 'results')
    results
  end

  def ticket_contents(json_search_results)
    tickets = json_search_results.select{ |r| r['url'] =~ /ticket/ }
    tickets.map do |ticket|
      yield(ticket)
    end
  end

  def users_from_search(json_search_results)
    user_links = json_search_results.map do |result|
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
  p subdomain
  raise 'ZendeskのAPI Tokenを、環境変数 ZENDESK_ACCESS_TOKEN にセットしてください' unless token
  raise 'Zendeskのsubdomainを、環境変数 ZENDESK_SUBDOMAIN にセットしてください' unless subdomain
  raise 'Zendeskの email を、環境変数 ZENDESK_EMAIL にセットしてください' unless email
  
  z = ZendeskParser.new(subdomain, email, token)
  if ARGV[0]
    search_query = "#{search_query} #{ARGV[0]}"
  else
    interval = (Date.today - 8).strftime("%Y-%m-%d")
    search_query = "#{search_query} created>#{interval}"
  end

  tickets = z.search(search_query)

  contents = z.ticket_contents(tickets) do |ticket|
    # binding.pry
    [
        ticket['id'],
        ticket['created_at'],
        ticket['subject'],
        ticket['description'].gsub(/[\r\n]+/, '<br>'),
        ticket['tags'].join(',')
    ].join("\t")
  end

  contents.each do |content|
    print content
    print "\n"
  end

  # users = z.users_from_search(tickets)
  # print users.sort.join(',')
  print "\n"
end