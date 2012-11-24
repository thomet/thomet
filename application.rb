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

  configure do
    require 'redis'
    uri = URI.parse(ENV["REDISTOGO_URL"] || "redis://127.0.0.1:6379")
    REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  end

  # Helpers
  helpers do
    def repository_text(repository)
      "<a href='#{repository.html_url}' class='repo_link'>#{repository.name}</a>: <span class='description'>#{repository.description}</span>"
    end

    def retrieve_tweets
      begin
        if cached_tweets = REDIS.get("tweets")
          YAML::load(cached_tweets)
        else
          unformatted_tweets = Twitter.user_timeline("tmetzmac")[0..3]
          tweets = unformatted_tweets.collect{ |tweet| auto_link(tweet.text) }
          REDIS.set("tweets", tweets.to_yaml)
          tweets
        end
      rescue Exception => e
        [e]
      end
    end

    def retrieve_repos
      begin
        if cached_tweets = REDIS.get("repositories")
          YAML::load(cached_tweets)
        else
          unformatted_repositories = Octokit.repositories("thomet")[0..3]
          repositories = unformatted_repositories.collect{ |repository| repository_text(repository) }
          REDIS.set("repositories", repositories.to_yaml)
          repositories
        end
      rescue Exception => e
        [e]
      end
    end
  end

  # Routes
  get '/' do
    @tweets = retrieve_tweets
    @repos = retrieve_repos

    haml :index
  end
end
