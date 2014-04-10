#!/usr/bin/env ruby
 
#gems required
require 'anemone'
require 'nokogiri'
require 'net/http'
require './model'
 
# Handles requests over HTTP
def read_http(url)
 uri = URI(url)
 Net::HTTP.get_response(uri)
end
  
# Handles requests over HTTPS and SSL
def read_https(url)
  response = nil
  uri = URI(url)
  
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.start do |http|
    response = Net::HTTP.get_response(uri)
  end
  response
end

# Method for the cases of different return errors when trying to connect 
def handle_error (url, res)
  puts "#{url} was not found"                if res.code.to_i == 404
  puts "#{url} requires authorization"       if res.code.to_i == 401
  puts "#{url} returns an application error" if res.code.to_i == 500
end
 
# User decides to display the list of parsed web urls 
def user_handle_already_found_urls (urls, site)
  puts "Do you want a list of already found urls? (Y/N)"
  choice = STDIN.gets.chomp.downcase
  case choice
  when "n"
    puts "OK"
  when "y"
    Url.show_already_found_urls(urls, site)
  else
    puts "Not acceptable input."
  end
end
 
# User decides the depth of the crawling
def user_handle_depth_limit
  puts "Choose the depth of the crawling (1-4)"
  choice = STDIN.gets.chomp.to_i
  case choice
  when 1
    return 1
  when 2
    return 2
  when 3
    return 3
  when 4
    return 4
  else
    puts "Not acceptable input."
  end
end
 
# Method checks if there is description meta data in header
def show_description (url, description)
  if description.nil?
    puts "Warning: (#{url}) needs a description."
  else 
    puts "Description of this URL (#{url}) is: #{description}."
  end
end
 
# Method checks if there are keywords and shows them in a list
def show_keywords (url, keywords)
  if keywords.nil?
    puts "Warning: (#{url}) needs keywords."
  else
    puts "The url's (#{url}) Keywords are:"     
    keywords.split(',').each do |keyword|
      puts "keyword: #{keyword}"
  end
  end
end

# Checks if keywords exist in the url of the site  
  def url_contains_keywords (url, keywords)
  unless keywords.nil?
    arr = keywords.split(',')
    arr.each do |keyword|
      if url.downcase.include? keyword.downcase
        puts "Found matching keyword: #{keyword}"
        return true
      end
    end   
    puts "Didn't find any keywords in the title of this URL (#{url})"
    return false
  end
end

# Checks if keywords exist in Description
def description_contains_keywords (description, keywords)
  if (keywords.nil? || description.nil?)
    puts "There are no keywords in the description of this URL: (#{url})"
    return false
  else  
    arr = keywords.split(',')
    arr.each do |keyword|
      if description.downcase.include?keyword.downcase
        puts "Found matching keyword: #{keyword}"
        return true
      end 
    end   
  end
end 

# Method checking if there is description or keywords 
def needs_seo (url)
  if url.description.nil? || url.keywords.nil?
    return true
  else
    return false
  end
end

# Method displaying if the site needs SEO or not 
def show_seo_evaluation (url, seo)
  if seo
    puts "Needs SEO! Keywords or Description were not found in this: (#{url})"
  end
end
 
# takes @site name as an argument
raise "missing url" unless ARGV.count == 1
  
@site = ARGV[0]
@site = 'http://' + ARGV[0] unless ARGV[0].start_with?('http://') || ARGV[0].start_with?('https://')
  
puts "Crawling site: #{@site}"
saved=0
 
@depth_limit = user_handle_depth_limit
 
# Anemone library crawls every page on the domain  
Anemone.crawl(@site, :discard_page_bodies => true, depth_limit: @depth_limit) do |anemone|
   
  @c = Crawl.first(site: @site)
  if !@c
    @c = Crawl.new
    @c.site = @site
    @c.save
  else
    urls = Url.already_found_urls @site
    user_handle_already_found_urls(urls, @site)
    break
  end
   
# Creats an empty array for storing all the url objects that will be crawled.
  urls = []
   
  anemone.on_every_page do |page|
    res = read_http(page.url)   if page.url.instance_of?(URI::HTTP)
    res = read_https(page.url)  if page.url.instance_of?(URI::HTTPS)
  
    puts "#{page.url} is a redirect to #{res['location']}" if res.code.to_i == 301
  
    if res.code.to_i == 200
      doc = Nokogiri::HTML(res.body)
      puts "Page URL: #{page.url} (depth: #{page.depth}, forms:#{doc.search("//form").count}) "
    end
     
    # Handles error for HTTP response codes.
    handle_error(page.url, res)
     
    @u = Url.first(url: page.url)
    if @u.nil?
      @u = Url.create_new_url_for_crawl(@u, @c, page, doc, res)
      show_keywords(page.url, @u.keywords)
      show_description(page.url, @u.description)
      description_contains_keywords(@u.description, @u.keywords)
      url_contains_keywords(@u.url, @u.keywords)
      show_seo_evaluation(page.url, needs_seo(@u))
    end
     
    # Adds the new url object in the array.
    urls.push(@u)
 
  end
   
  # Sets the relationship to the crawler object.
  @c.urls = urls
end