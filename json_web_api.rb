require 'net/http'
require 'cgi'
require 'uri'
require 'base64'
require 'json'

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