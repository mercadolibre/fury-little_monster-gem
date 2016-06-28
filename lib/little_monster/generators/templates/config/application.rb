require 'bundler'
Bundler.require(:default)

LittleMonster.configure do |conf|
  #lib/little_monster.rb:25
  conf.api_url = "http://pepe.hongo.com" 
end

require_relative "enviroments/#{LittleMonster.env}"
