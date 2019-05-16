require 'sinatra/base'
require 'sinatra/reloader'

class UrbanFiesta < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  set :root, File.dirname(__FILE__)

  get '/' do
    'something something'
  end
end
