require 'rubygems'
require 'sinatra'
require 'haml'
require 'sass'
require 'rack-google-analytics'

require 'sinatra/assetpack'

class Application < Sinatra::Base
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

  # Routes
  get '/' do
    haml :index
  end
end
