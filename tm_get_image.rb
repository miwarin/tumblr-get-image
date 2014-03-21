#!/usr/bin/ruby

# -*- encoding: utf-8 -*-

require 'open-uri'
require 'tumblife'
require 'yaml'
require 'pp'

class Cache
  
  def initialize(cache_path)
    @path = cache_path
    read()
  end
  
  def read
    @cache = YAML.load_file(@path) if FileTest.file?(@path)
    @cache ||= []
  end
  
  def write(contents)
    @cache << contents
    File.open(@path, "w").write(YAML.dump(contents))
  end
  
  def include?(contents)
    return @cache.include?(contents)
  end
  
end

class Tumblove
  def initialize(config_path)
  
    @config = YAML.load_file(config_path)
    
    Tumblife.configure {|config|
      config.consumer_key = @config["api"]["consumer_key"]
      config.consumer_secret = @config["api"]["consumer_secret"]
      config.oauth_token = @config["api"]["oauth_token"]
      config.oauth_token_secret = @config["api"]["oauth_secret"]
    }
        
    @client = Tumblife.client
    @base_hostname = @config["post"]["host_name"]
    @cache = Cache.new(File.join(@config["cache"]["directory"], @config["cache"]["filename"]))
  end

  def downloaded?(uri)
    return @cache.include?(uri)
  end
  
  def downloaded(uri)
    @cache.write(uri)
  end
  
  def write(uri)
    return if downloaded?(uri)
    
    filename = File.join(@config["post"]["save_dir"], File.basename(uri))
    
    puts "#{uri} => #{filename}"

    open(filename, 'wb') {|outfile|
      open(uri) {|infile|
        outfile.write(infile.read)
      }
    }
    downloaded(uri)
  end

  def max_photos(post)
    photos ||= []
    post.photos.each {|photo|
      max_size = 0
      max_uri = ''

      photo.alt_sizes.each {|alt_size_photo|
        size = alt_size_photo.width
        if size > max_size
          max_size = size
          max_uri = alt_size_photo.url
        end
      }
      photos << max_uri
    }
    return photos
  end

  def get
    posts = @client.posts(@base_hostname)
    posts.posts.each {|post|
      next if post.photos == nil
      photos = max_photos(post)
      photos.each {|photo|
        write(photo)
      }
    }
  end

end


def main(argv)
  config_path = argv[0].nil? ? ENV['HOME'] + '/tumblr.yaml' : argv[0]
  t = Tumblove.new(config_path)
  t.get()
end

main(ARGV)

