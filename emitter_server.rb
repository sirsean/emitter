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
require 'processor/AuthenticatedProcessor'
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

# set up pre/post-processors for any actions that'll require them
authenticatedProcessor = AuthenticatedProcessor.new(settings, userDao)
postTweetProcessors = [
    ForwardTweetProcessor.new(settings, remoteServerService)
]
followProcessors = [
    ForwardFollowProcessor.new(settings, remoteServerService)
]
unfollowProcessors = [
    ForwardUnfollowProcessor.new(settings, remoteServerService)
]

# set up the remoted services
publicService = PublicService.new(settings, userDao, tweetDao)
authenticatedService = AuthenticatedService.new(settings, userDao, tweetDao, postTweetProcessors, followProcessors, unfollowProcessors)
serverService = ServerService.new(settings, userDao, tweetDao)

# these methods need to run the AuthenticatedProcessor before they can be called
authenticated_methods = [
    "authenticate",
    "saveUserInfo",
    "follow",
    "unfollow",
    "emit",
    "getTimeline",
]

post '/api/?' do
    payload = JSON.parse(params[:payload])
    puts payload.inspect
    begin
        if authenticated_methods.include?(payload["method"])
            authenticatedProcessor.process(payload)
        end
        result = 
            case payload["method"]
                when "createUser"
                    publicService.createUser(payload["user"])
                when "getUserInfo"
                    publicService.getUserInfo(payload["username"])
                when "getFollowing"
                    publicService.getFollowing(payload["username"])
                when "getFollowers"
                    publicService.getFollowers(payload["username"])
                when "getEmissions"
                    publicService.getEmissions(payload["username"], payload["after_date"], payload["before_date"])
                when "authenticate"
                    authenticatedService.authenticate(payload["username"], payload["password"])
                when "saveUserInfo"
                    authenticatedService.saveUserInfo(payload["username"], payload["user"])
                when "follow"
                    authenticatedService.follow(payload["username"], payload["to_follow"])
                when "unfollow"
                    authenticatedService.unfollow(payload["username"], payload["to_unfollow"])
                when "emit"
                    authenticatedService.emit(payload["username"], payload["metadata"])
                when "getTimeline"
                    authenticatedService.getTimeline(payload["username"], payload["after_date"], payload["before_date"])
                when "getApiVersion"
                    serverService.getApiVersion()
                when "forwardFollow"
                    serverService.forwardFollow(payload["username"], payload["follower"])
                when "forwardUnfollow"
                    serverService.forwardUnfollow(payload["username"], payload["follower"])
                when "forwardEmit"
                    serverService.forwardEmit(payload["usernames"], payload["emission"])
            end
    rescue
        puts "Error"
        puts $ERROR_INFO.inspect
        result = {"error" => $ERROR_INFO.inspect}
    end
    if not result
        result = {"error"=>"No such method", "method"=>payload["method"]}
    end

    JSON.generate(result)
end

get '/test/?' do
    haml :testForm
end

# these are for the web UI

get '/?' do
    haml :index
end

# public (don't require authentication)

=begin
    Display the signup screen
=end
get '/signup/?' do
    haml :signup
end

=begin
    Process a signup

    This should create a user, set up a session and move along to the user's main page
=end
post '/signup/?' do
    puts "signup!"
    puts params.inspect
    @username = params["username"]
    @password1 = params["password1"]
    @password2 = params["password2"]
    @email = params["email"]
    @pretty_name = params["pretty_name"]

    @errors  = []
    if not @username or @username.length < 3
        @errors << "Invalid username"
    end
    if not @password1 or @password1.length < 4
        @errors << "Invalid password"
    end
    if not @password2 or @password2.length < 4
        @errors << "Invalid repeat password"
    end
    if @password1 != @password2
        @errors << "Passwords must match"
    end
    if not @email or @email.length < 5
        @errors << "Invalid email address"
    end
    if not @pretty_name or @pretty_name.length < 3
        @errors << "Invalid full name"
    end

    if @errors.length == 0
        user = {
            "username" => @username,
            "password" => @password1,
            "email" => @email,
            "pretty_name" => @pretty_name
        }

        # save the user
        begin
            user = publicService.createUser(user)
        rescue
            @errors << $ERROR_INFO.message
            return haml :signup
        end

        # set up the session here to effective log them in

        redirect "/user/#{user['username']}/"
    else
        # there were errors, so we need to render the signup screen again
        haml :signup
    end
end

=begin
    Display the login screen
=end
get '/login/?' do
end

=begin
    Process a login

    This should authenticate the user, set up a session and move along to the user's main page
=end
post '/login/?' do
end

=begin
    Destroy the session and go back to the homepage
=end
get '/logout/?' do
end

=begin
    A user's main page that displays a list of their emissions

    If there is a logged in user AND it's the user that's being viewed, then we show the timeline; otherwise, we just show the emissions they posted
=end
get '/user/:username/?' do |username|
    @user = publicService.getUserInfo(username)
    @emissions = publicService.getEmissions(username)

    "User #{@user['username']} has #{@emissions.length} emissions"
end

=begin
    Show a list of the users that a user is following
=end
get '/user/:username/following/?' do |username|
    @user = publicService.getUser(username)
    @following = publicService.getFollowing(username)

    "User #{@user['username']} is following #{@following.length} users"
end

=begin
    Show a list of the users that are following a particular user
=end
get '/user/:username/followers/?' do |username|
    @user = publicService.getUser(username)
    @followers = publicService.getFollowers(username)

    "User #{@user['username']} has #{@followers.length} followers"
end

=begin
    Show an individual emission
=end
get '/emission/:emission_id/?' do |emission_id|
    @emission = tweetDao.get(Mongo::ObjectID.from_string(emission_id))

    @emission.inspect
end

# protected (require authentication)

=begin
    Follow another user
=end
post '/user/:username/follow/?' do |username|
end

=begin
    Unfollow another user
=end
post '/user/:username/unfollow/?' do |username|
end

=begin
    Post a new emission
=end
post '/user/:username/emit/?' do |username|
end

=begin
    Update an existing emission
=end
post '/emission/:emission_id/update/?' do |emission_id|
end
