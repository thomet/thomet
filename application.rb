require 'rubygems'
require 'sinatra'
require 'haml'
require 'sass'
require 'twitter'
require 'octokit'
require 'rack-google-analytics'
require 'twitter-text'

require 'sinatra/assetpack'

class Application < Sinatra::Base
  # Formatting tweets
  include Twitter::Autolink

  set :logging, true

  set :root, File.dirname(__FILE__)
  register Sinatra::AssetPack

  assets {
    serve '/javascripts', from: 'assets/javascripts'
    serve '/stylesheets', from: 'assets/stylesheets'
    serve '/images',      from: 'assets/images'

    css :application, '/stylesheets/application.css', [
      '/stylesheets/screen.css'
    ]

    css_compression :sass
  }

  # Google Analytics
  use Rack::GoogleAnalytics, :tracker => 'UA-36558630-1'

  MAX_ELEMENTS_ON_SITE = 6

  configure do
    require 'redis'
    uri = URI.parse(ENV["REDISTOGO_URL"] || "redis://127.0.0.1:6379")
    REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  end

  # Helpers
  helpers do
    def shorten(text, length)
      text.length > length ? "#{text[0..length-3]}..." : text
    end

    def repository_text(repository)
      "<a href='#{repository.html_url}' class='repo_link'>#{repository.name}</a>: <span class='description'>#{repository.description}</span>"
    end

    def retrieve_tweets(count)
      begin
        if cached_tweets = REDIS.get("tweets")
          tweets = YAML::load(cached_tweets)
        else
          unformatted_tweets = Twitter.user_timeline("tmetzmac", :count => count, :trim_user => true)
          tweets = unformatted_tweets.collect{ |tweet| {:text => auto_link(tweet.text), :date => tweet.created_at} }
          REDIS.set("tweets", tweets.to_yaml)
          REDIS.expire("tweets", 43200)
        end
        tweets.map{ |tweet| tweet.merge({:icon_class => 'icon-twitter', :box_class => 'twitter'}) }
      rescue Exception => e
        logger.error e
        []
      end
    end

    def retrieve_repos(count)
      begin
        if cached_tweets = REDIS.get("repositories")
          repositories = YAML::load(cached_tweets)
        else
          unformatted_repositories = Octokit.repositories("thomet")[0...count]
          repositories = unformatted_repositories.collect{ |repository| { :text => shorten(repository_text(repository), 275), :date => Time.parse(repository.updated_at) } }
          REDIS.set("repositories", repositories.to_yaml)
          REDIS.expire("repositories", 43200)
        end
        repositories.map{ |repository| repository.merge({:icon_class => 'icon-github', :box_class => 'github'}) }
      rescue Exception => e
        logger.error e
        []
      end
    end

    def cc_html(options={}, &blk)
      attrs = options.map { |(k, v)| " #{h k}='#{h v}'" }.join('')
      [ "<!--[if lt IE 7 ]> <html#{attrs} class='ie ie6'> <![endif]-->",
        "<!--[if IE 7 ]>    <html#{attrs} class='ie ie7'> <![endif]-->",
        "<!--[if IE 8 ]>    <html#{attrs} class='ie ie8'> <![endif]-->",
        "<!--[if (gte IE 9)|!(IE)]><!--> <html#{attrs}> <!--<![endif]-->",
        capture_haml(&blk).strip,
        "</html>"
      ].join("\n")
    end

    def h(str); Rack::Utils.escape_html(str); end
  end

  # Routes
  get '/' do
    @elements = []
    @elements += retrieve_repos(3)
    @elements += retrieve_tweets(MAX_ELEMENTS_ON_SITE - @elements.length)
    @elements.sort_by!{|element| element[:date] }.reverse!

    haml :index
  end
end
