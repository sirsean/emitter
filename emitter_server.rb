require 'rubygems'
require 'sinatra'
require 'haml'
require 'json'
require 'mongo'
require 'Time'
require 'service/PublicService'
require 'service/AuthenticatedService'
require 'service/ServerService'
require 'dao/UserDao'
require 'dao/TweetDao'
require 'dao/SessionDao'
require 'remote/RemoteServerService'
require 'processor/ForwardTweetProcessor'
require 'processor/ForwardFollowProcessor'
require 'processor/ForwardUnfollowProcessor'
require 'processor/AuthenticatedProcessor'
require 'processor/InsertEmissionIntoLocalTimelineProcessor'
require 'Settings'

enable :sessions

# load the settings
settings = Settings::load()

# connect to the Mongo database
db = Mongo::Connection.new.db(settings["db_name"])

# set up the DAOs
userDao = UserDao.new(db["users"])
tweetDao = TweetDao.new(db["tweets"])
sessionDao = SessionDao.new(db["sessions"])

# set up helper services
remoteServerService = RemoteServerService.new

# set up pre/post-processors for any actions that'll require them
authenticatedProcessor = AuthenticatedProcessor.new(settings, userDao)
postTweetProcessors = [
    InsertEmissionIntoLocalTimelineProcessor.new(settings, userDao),
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
    @session = sessionDao.get(session["session_id"])
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
        @session = {"username" => user["username"]}
        sessionDao.save(@session)
        session["session_id"] = @session[:_id]

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
    @session = sessionDao.get(session["session_id"])
    puts @session
    if @session
        puts "already logged in"
        redirect "/home/"
    else
        haml :login
    end
end

=begin
    Process a login

    This should authenticate the user, set up a session and move along to the user's main page
=end
post '/login/?' do
    if userDao.authenticateUser(params["username"], params["password"])
        @session = {"username" => params["username"]}
        sessionDao.save(@session)
        session["session_id"] = @session[:_id]

        redirect "/home/"
    else
        @username = params["username"]
        @errors = [ "Invalid login" ]

        haml :login
    end
end

=begin
    Destroy the session and go back to the homepage
=end
get '/logout/?' do
    @session = sessionDao.get(session["session_id"])
    puts @session
    if @session
        puts "deleting session"
        sessionDao.delete(@session)
        session["session_id"] = nil
    end

    redirect "/"
end

=begin
    The logged-in user's home screen, which shows their timeline and a form to emit

    If you're not logged in, you can't come here
=end
get '/home/?' do
    @session = sessionDao.get(session["session_id"])
    puts @session
    if @session
        @user = userDao.getByUsername(@session["username"])
        @emissions = tweetDao.getTweets(@user["timeline"])
        haml :home
    else
        puts "not logged in"
        redirect "/login/"
    end
end

=begin
    A user's main page that displays a list of their emissions
=end
get '/user/:username/?' do |username|
    @session = sessionDao.get(session["session_id"])
    @user = userDao.getByUsername(username)
    @emissions = publicService.getEmissions(username)
    @is_you = (@session["username"] == username)
    if not @is_you
        @is_following = userDao.isFollowing(@session["username"], {"username" => username, "timeline" => settings["timeline"]})
    end

    haml :user
end

=begin
    Show a list of the users that a user is following
=end
get '/user/:username/following/?' do |username|
    @session = sessionDao.get(session["session_id"])
    @user = userDao.getByUsername(username)
    @following = publicService.getFollowing(username)

    haml :following
end

=begin
    Show a list of the users that are following a particular user
=end
get '/user/:username/followers/?' do |username|
    @session = sessionDao.get(session["session_id"])
    @user = userDao.getByUsername(username)
    @followers = publicService.getFollowers(username)

    haml :followers
end

=begin
    Show an individual emission
=end
get '/emission/:emission_id/?' do |emission_id|
    @session = sessionDao.get(session["session_id"])
    @emission = tweetDao.get(Mongo::ObjectID.from_string(emission_id))

    haml :emission
end

# protected (require authentication)

=begin
    Follow another user
=end
get '/user/:username/follow/?' do |username|
    @session = sessionDao.get(session["session_id"])
    if @session
        authenticatedService.follow(@session["username"], {"username" => username, "timeline" => settings["timeline"]})
        redirect "/user/#{username}/"
    else
        redirect "/login/"
    end
end

=begin
    Unfollow another user
=end
get '/user/:username/unfollow/?' do |username|
    @session = sessionDao.get(session["session_id"])
    if @session
        authenticatedService.unfollow(@session["username"], {"username" => username, "timeline" => settings["timeline"]})
        redirect "/user/#{username}/"
    else
        redirect "/login/"
    end
end

=begin
    Post a new emission
=end
post '/emit/?' do
    @session = sessionDao.get(session["session_id"])
    if @session
        puts params.inspect
        authenticatedService.emit(@session["username"], params)
        redirect "/home"
    else
        redirect "/login"
    end
end

=begin
    Update an existing emission
=end
post '/emission/:emission_id/update/?' do |emission_id|
end

helpers do

    def display_emission(emission)
        @emission = emission
        haml :partial_emission, :layout => false
    end

end
