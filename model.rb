require 'data_mapper'
require 'dm-sqlite-adapter'

# Open the database in the working directory with the name
DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/project.db")

# Properties of Url entity 
class Url
  include DataMapper::Resource
  
  property :id,          Serial
  property :url,         Text,       :required=>true
  property :code,        Integer
  property :redirect,    Text
  property :depth,       Integer
  property :forms,       Text
  property :href,        Text
  property :keywords,    Text
  property :keywords_count, Integer
  property :description, Text
  property :created_at,  DateTime,   :default=>DateTime.now
  property :updated_at,  DateTime,   :default=>DateTime.now
   
  belongs_to :crawl, 'Crawl'
   
  # Use of 'url.like' => "#{site}%" predicate to find all url objects
  # that begin with the value of the site parameter.
  # Class method for handling urls already crawled.
  def self.already_found_urls (site)   
    return arr = self.all('url.like' => "#{site}%")
  end
  
  # Method showing the urls found in the domain.
  def self.show_already_found_urls (urls, site) 

    #for all urls found 
    puts "Already found URLs for #{site}:"
    urls.each do |url|
      puts "URL: #{url.url}"
    end
  end
  
  # Method creating a new Url entity for links found in the domain
  def self.create_new_url_for_crawl (u, crawl, page, doc, res)
    u = self.new
    u.url = page.url
    u.depth = page.depth
    u.forms = doc.css("form").map { |a| (a['name'].nil?)? "nonamed":a['name'] }.compact.to_s.gsub("\n", ",") unless doc.nil?
    u.href = doc.css('div a').map { |link| (link['href'].nil?)? "":link['href'] }.compact.to_s.gsub("\n", ",") unless doc.nil?
    u.keywords = doc.xpath('//meta[@name="keywords"]/@content').map(&:value).compact.to_s.gsub("\n", ",") unless doc.nil?
    u.description = doc.xpath('//meta[@name="description"]/@content').map(&:value).compact.to_s.gsub("\n", ",") unless doc.nil?
    u.code = res.code.to_i
    u.redirect = res['location'] if res.code.to_i == 301
    u.crawl = crawl
    u.keywords_count = u.keywords.split(',').count unless u.keywords.nil?
    u.save
     
    return u
  end
   
end

# Propery of entity Crawl ~> will keep domain name 
class Crawl
  include DataMapper::Resource 
   
  property :id, Serial
  property :site, Text
  property :created_at,  DateTime,   :default=>DateTime.now
  property :updated_at,  DateTime,   :default=>DateTime.now
   
  has n, :urls
end

# Call finalize before your application starts accessing the models. 
DataMapper.finalize.auto_upgrade!