#!/usr/bin/env ruby
# Checks links and flags catalogue sections that need human editorial review.

require 'date'
require 'net/http'
require 'uri'

source = File.read(File.expand_path('../resources.js', __dir__))
today = Date.today

review_rules = {
  'currentReviewedAt' => 35,
  'evergreenReviewedAt' => 100,
  'sourcesReviewedAt' => 35,
  'toolsReviewedAt' => 35,
  'connectionsReviewedAt' => 35
}

problems = []
review_rules.each do |field, maximum_days|
  value = source[/#{field}:\s*'([^']+)'/, 1]
  if value.nil?
    problems << "Missing #{field}"
    next
  end
  age = (today - Date.iso8601(value)).to_i
  problems << "#{field} is #{age} days old (limit #{maximum_days})" if age > maximum_days
end

def response_for(url, limit = 4)
  raise 'too many redirects' if limit.zero?
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == 'https'
  http.open_timeout = 12
  http.read_timeout = 18
  response = http.request(Net::HTTP::Get.new(uri.request_uri, 'User-Agent' => 'Dragon-Learning-Link-Check/1.0'))
  return response_for(URI.join(uri, response['location']).to_s, limit - 1) if response.is_a?(Net::HTTPRedirection) && response['location']
  response
end

urls = source.scan(/(?:url|learnUrl):\s*'([^']+)'/).flatten.uniq
urls.each do |url|
  begin
    status = response_for(url).code.to_i
    if [404, 410].include?(status)
      problems << "Broken link #{status}: #{url}"
    elsif status == 403 || status == 429 || status >= 500
      warn "Needs manual check #{status}: #{url}"
    else
      puts "OK #{status}: #{url}"
    end
  rescue StandardError => error
    problems << "Could not reach #{url}: #{error.class}"
  end
end

if problems.any?
  warn "\nCatalogue check failed:"
  problems.each { |problem| warn "- #{problem}" }
  exit 1
end

puts "\nCatalogue check passed for #{urls.length} unique links."
