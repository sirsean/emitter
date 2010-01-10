require 'rubygems'
require 'sinatra'
require 'haml'
require 'json'
require 'mongo'
require 'service/PublicService'
require 'service/AuthenticatedService'
require 'service/ServerService'
require 'dao/UserDao'
require 'dao/TweetDao'
require 'remote/RemoteServerService'
require 'processor/ForwardTweetProcessor'
require 'processor/ForwardFollowProcessor'
require 'processor/ForwardUnfollowProcessor'
require 'Settings'

# load the settings
settings = Settings::load()

# connect to the Mongo database
db = Mongo::Connection.new.db(settings["db_name"])

# set up the DAOs
userDao = UserDao.new(db["users"])
tweetDao = TweetDao.new(db["tweets"])

# set up helper services
remoteServerService = RemoteServerService.new

# set up post-processors for any actions that'll require them
postTweetProcessors = [
    ForwardTweetProcessor.new(settings, remoteServerService)
]
followProcessors = [
    ForwardFollowProcessor.new(settings, remoteServerService)
]
unfollowProcessors = [
    ForwardUnfollowProcessor.new(settings, remoteServerService)
]

# set up the remoted services, in order of preference (note that no method name can be shared across services)
services = [
    PublicService.new(settings, userDao, tweetDao),
    AuthenticatedService.new(settings, userDao, tweetDao, postTweetProcessors, followProcessors, unfollowProcessors),
    ServerService.new(settings, userDao, tweetDao),
]

post '/api/?' do
    payload = JSON.parse(params[:payload])
    puts payload.inspect
    for service in services
        begin
            result = service.send(payload['method'], payload)
            break
        rescue NoMethodError
            puts "Failed"
            puts $ERROR_INFO.inspect
        rescue
            puts "There was actually an error!"
            puts $ERROR_INFO.inspect
            result = {"error" => "There was actually an error"}
        end
    end
    if not result
        result = {"error"=>"No such method", "method"=>payload["method"]}
    end

    JSON.generate(result)
end

get '/test/?' do
    haml :testForm
end

get '/?' do
    haml :index
end

