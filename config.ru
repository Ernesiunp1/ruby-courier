# config.ru
$stdout.sync = true

require 'bundler'
Bundler.require

# Connect database
require './database'

require './app'
run Sinatra::Application
