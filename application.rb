require 'rubygems'
require 'sinatra'
require 'haml'
require 'rack-google-analytics'

use Rack::GoogleAnalytics, :tracker => 'UA-36558630-1'

get '/' do
  haml :index
end