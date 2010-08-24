require 'rubygems'
require 'sinatra'
require 'haml'
require 'mongo'
require 'mongo_mapper'

enable :sessions

#load the config
config = YAML::load(File.open('config.yaml'))

# connect to the database
MongoMapper.connection = Mongo::Connection.new(config["db_hostname"])
MongoMapper.database = config["db_name"]
if config["db_username"]
    MongoMapper.connect[config["db_name"]].authenticate(config["db_username"], config["db_password"])
end

# load the models AFTER connecting to the database, because of the way MongoMapper handles indexes
require 'model/User'
require 'model/Post'
require 'model/Conversation'

before do
    puts "before request"
    if session["user_id"]
        puts "Logged in user id: #{session["user_id"]}"
        @logged_in_user = User.find(session["user_id"])
        puts "Username: #{@logged_in_user.username}"
    end

    @flash = session.delete("flash")
    @site_hostname = config["site_hostname"]
end

get "/?" do
    haml :index
end

get "/signup/?" do
    haml :signup
end

post "/signup/?" do
    puts "signing up!"

    @username = params["username"]
    @password1 = params["password1"]
    @password2 = params["password2"]
    @email = params["email"]
    @pretty_name = params["pretty_name"]

    @errors = []
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

    # make sure the username is unique!!!

    if @errors.empty?
        user = User.create({
            :username => @username,
            :password => @password1,
            :pretty_name => @pretty_name,
            :email => @email,
            :follower_ids => [],
            :following_ids => [],
            :mention_post_ids => [],
            :num_followers => 0,
            :num_following => 0,
            :num_mentions => 0
        })
        user.save

        session["user_id"] = user.id
        flash "Welcome to Emitter!"
        redirect "/home/"
    else
        haml :signup
    end
end

get "/login/?" do
    if @logged_in_user
        redirect_back "/home/"
    else
        haml :login
    end
end

post "/login/?" do
    puts "trying to log in"
    if @logged_in_user
        redirect_back "/home/"
    else
        @username = params["username"]
        password = params["password"]
        user = User.get_by_username_and_password(@username, password)
        if user
            puts "successful login"
            session["user_id"] = user.id
            redirect_back "/home/"
        else
            puts "failed login"
            @errors = ["Invalid login"]
            haml :login
        end
    end
end

get "/logout/?" do
    if @logged_in_user
        session.delete("user_id")
    end
    redirect "/"
end

get "/profile/?" do
    set_redirect
    if @logged_in_user
        haml :profile
    else
        redirect "/login/"
    end
end

post "/profile/?" do
    if @logged_in_user
        @pretty_name = params["pretty_name"]
        @email = params["email"]
        @bio = params["bio"]

        @errors = []
        if not @pretty_name or @pretty_name.length < 3
            @errors << "Invalid name"
        end
        if not @email or @email.length < 3
            @errors << "Invalid email"
        end

        if @errors.empty?
            @logged_in_user.pretty_name = @pretty_name
            @logged_in_user.email = @email
            @logged_in_user.bio = @bio
            @logged_in_user.save

            flash "Profile updated"
            redirect "/profile/"
        else
            haml :profile
        end
    else
        redirect "/login/"
    end
end

get "/profile/password/?" do
    set_redirect
    haml :profile_password
end

post "/profile/password/?" do
    if @logged_in_user
        currentPassword = params["currentPassword"]
        password1 = params["password1"]
        password2 = params["password2"]

        @errors = []
        if @logged_in_user.password != currentPassword
            @errors << "Incorrect current password"
        end
        if not password1 or password1.length < 4
            @errors << "Invalid new password"
        end
        if not password2 or password2.length < 4
            @errors << "Invalid repeat password"
        end
        if password1 != password2
            @errors << "Passwords must match"
        end

        if @errors.empty?
            @logged_in_user.password = password1
            @logged_in_user.save

            flash "Password updated"
            redirect "/profile/password/"
        end

        haml :profile_password
    else
        redirect "/login/"
    end
end

get "/profile/picture/?" do
    set_redirect
    if @logged_in_user
        haml :profile_picture
    else
        redirect "/login/"
    end
end

post "/profile/picture/?" do
    if @logged_in_user
        if params[:file] and (tmpfile = params[:file][:tempfile]) and (filename = params[:file][:filename])
            extension = filename.split(".")[-1]
            File.open("public/profile_pictures/#{@logged_in_user.username}.#{extension}", "w") { |f| f.write(tmpfile.read()) }

            flash "Profile picture updated"
            redirect_back "/profile/picture/"
        else
            @errors = ["Missing file"]
            haml :profile_picture
        end
    else
        redirect "/login/"
    end
end

get "/home/?" do
    set_redirect
    if @logged_in_user
        @emissions = Post.get_user_timeline(@logged_in_user.id)
        haml :home
    else
        redirect "/login/"
    end
end

get "/user/:username/?" do |username|
    puts "viewing #{username}"
    set_redirect
    @user = User.get_by_username(username)
    puts "got user id #{@user.id}"
    @emissions = Post.get_by_author_id(@user.id)
    if @logged_in_user
        @is_you = (@user.id == @logged_in_user.id)
        @is_following = @logged_in_user.is_following?(@user.id)
    end
    haml :user
end

get "/user/:username/following/?" do |username|
    set_redirect
    @user = User.get_by_username(username)
    @following = User.get_by_user_ids(@user.following_ids)
    haml :following
end

get "/user/:username/followers/?" do |username|
    set_redirect
    @user = User.get_by_username(username)
    @followers = User.get_by_user_ids(@user.follower_ids)
    haml :followers
end

get "/user/:username/mentions/?" do |username|
    set_redirect
    @user = User.get_by_username(username)
    @emissions = Post.get_by_mentioned_user_id(@user.id)
    haml :mentions
end

get "/emission/:post_id/?" do |post_id|
    set_redirect
    @emission = Post.find(post_id)
    @user = User.find(@emission.author_id)
    haml :emission
end

get "/user/:username/follow/?" do |username|
    if @logged_in_user
        user = User.get_by_username(username)

        if not user.follower_ids
            user.follower_ids = []
        end
        if not @logged_in_user.following_ids
            @logged_in_user.following_ids = []
        end

        if not user.follower_ids.include?(@logged_in_user.id)
            user.follower_ids << @logged_in_user.id
            if not user.num_followers
                user.num_followers = 0
            end
            user.num_followers += 1
            user.save
        end
        if not @logged_in_user.following_ids.include?(user.id)
            @logged_in_user.following_ids << user.id
            if not @logged_in_user.num_following
                @logged_in_user.num_following = 0
            end
            @logged_in_user.num_following += 1
            @logged_in_user.save
        end

        flash "You are now following #{username}"
        redirect_back "/user/#{username}/"
    else
        redirect "/login/"
    end
end

get "/user/:username/unfollow/?" do |username|
    if @logged_in_user
        user = User.get_by_username(username)

        if @logged_in_user.is_following?(user.id)
            @logged_in_user.following_ids.delete(user.id)
            @logged_in_user.num_following -= 1
            @logged_in_user.save
        end
        if user.is_follower?(@logged_in_user.id)
            user.follower_ids.delete(@logged_in_user.id)
            user.num_followers -= 1
            user.save
        end

        flash "You are no longer following #{username}"
        redirect_back "/user/#{username}/"
    else
        redirect "/login/"
    end
end

post "/emit/?" do
    if @logged_in_user
        puts "emitting..."
        post = Post.emit({
            :author => @logged_in_user,
            :content => params["content"],
            :in_reply_to => params["in_reply_to"]
        })

        flash "Emission posted"
        redirect_back "/home/"
    else
        redirect "/login/"
    end
end

post "/emission/:post_id/update/?" do |post_id|
    redirect "/emission/#{post_id}/"
end

get "/conversation/:conversation_id/?" do |conversation_id|
    set_redirect

    @conversation = Conversation.find(conversation_id)
    @conversation_users = User.get_by_user_ids(@conversation.user_ids)
    @emissions = Post.get_by_post_ids(@conversation.post_ids)

    if @logged_in_user
        @is_participating = @conversation.user_ids.include?(@logged_in_user.id)
    end

    haml :conversation
end

get "/conversation/:conversation_id/join/?" do |conversation_id|
    if @logged_in_user
        conversation = Conversation.find(conversation_id)
        conversation.add_user(@logged_in_user.id)
        conversation.save

        flash "Joined conversation"
        redirect_back "/conversation/#{conversation.id}/"
    else
        redirect "/login/"
    end
end

get "/conversation/:conversation_id/leave/?" do |conversation_id|
    if @logged_in_user
        conversation = Conversation.find(conversation_id)
        conversation.remove_user(@logged_in_user.id)
        conversation.save

        flash "You are no longer participating in this conversation"
        redirect_back "/conversation/#{conversation.id}/"
    else
        redirect "/login/"
    end
end

get "/search/?" do
    set_redirect
    @term = params["term"]

    if @term and not @term.empty?
        @emissions = Post.search_content(@term)
    end

    haml :search
end

helpers do
    def display_emission(emission)
        @emission = emission
        haml :partial_emission, :layout => false
    end

    def display_userinfo(title, userInfo)
        @title = title
        @userInfo = userInfo
        haml :partial_userinfo, :layout => false
    end

    def display_errors(errors)
        @errors = errors
        haml :partial_errors, :layout => false
    end

    def display_profile_menu(currentProfileScreen)
        @currentProfileScreen = currentProfileScreen
        haml :partial_profile_menu, :layout => false
    end

    def display_user_in_list(user)
        @userInfo = user
        haml :partial_user_in_list, :layout => false
    end
end

=begin
    Re-opening the String class to add some methods that we're going to use in our templates
=end
class String

=begin
    Parse the String for usernames (with an @ at the start) and convert them to Markdown-syntax links to the user's page
=end
    def userlinks
        self.gsub(/@([a-zA-Z0-9\-_]+[a-zA-Z0-9])/, "[\\0](/user/\\1/)")
    end

    def extract_usernames
        self.scan(/@[a-zA-Z0-9\-_]+[a-zA-Z0-9]/).map{|username| username.gsub(/@/, "") }
    end

end

def flash(message)
    session["flash"] = message
end

def set_redirect
    session["redirect_url"] = request.fullpath
end

def redirect_back(default=nil)
    redirect_url = session.delete("redirect_url")
    if not redirect_url
        redirect_url = default
    end
    redirect redirect_url
end


#load the routes for each module's functionality
