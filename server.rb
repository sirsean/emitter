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

before do
    puts "before request"
    if session["user_id"]
        puts "Logged in user id: #{session["user_id"]}"
        @logged_in_user = User.find(session["user_id"])
        puts "Username: #{@logged_in_user.username}"
    end

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
            :num_followers => 0,
            :num_following => 0
        })
        user.save

        session["user_id"] = user.id
        redirect "/home/"
    else
        haml :signup
    end
end

get "/login/?" do
    if @logged_in_user
        redirect "/home/"
    else
        haml :login
    end
end

post "/login/?" do
    if @logged_in_user
        redirect "/home/"
    else
        @username = params["username"]
        password = params["password"]
        user = User.get_by_username_and_password(@username, password)
        if user
            session["user_id"] = user.id
            redirect "/home/"
        else
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
            redirect "/profile/"
        else
            haml :profile
        end
    else
        redirect "/login/"
    end
end

get "/profile/password/?" do
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
            @passwordUpdated = true
        end

        haml :profile_password
    else
        redirect "/login/"
    end
end

get "/profile/picture/?" do
    haml :profile_picture
end

post "/profile/picture/?" do
    @errors = ["Can't update your picture"]
    haml :profile_picture
end

get "/home/?" do
    puts "Home, logged in user: #{session["user_id"]}"
    if @logged_in_user
        @emissions = Post.get_user_timeline(@logged_in_user.id)
        haml :home
    else
        redirect "/login/"
    end
end

get "/user/:username/?" do |username|
    puts "viewing #{username}"
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
    @user = User.get_by_username(username)
    @following = User.get_by_user_ids(@user.following_ids)
    haml :following
end

get "/user/:username/followers/?" do |username|
    @user = User.get_by_username(username)
    @followers = User.get_by_user_ids(@user.follower_ids)
    haml :followers
end

get "/user/:username/mentions/?" do |username|
    @user = User.get_by_username(username)
    @emissions = Post.get_by_mentioned_user_id(@user.id)
    haml :mentions
end

get "/emission/:post_id/?" do |post_id|
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

        redirect "/user/#{username}/"
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

        redirect "/user/#{username}/"
    else
        redirect "/login/"
    end
end

post "/emit/?" do
    if @logged_in_user
        puts "emitting..."
        puts params["content"]
        mentioned_usernames = params["content"].extract_usernames
        puts mentioned_usernames
        mentioned_users = User.get_by_usernames(mentioned_usernames)
        mentioned_user_ids = mentioned_users.map{|u| u.id}
        puts mentioned_user_ids
        post = Post.create({
            :author_id => @logged_in_user.id,
            :author_username => @logged_in_user.username,
            :author_pretty_name => @logged_in_user.pretty_name,
            :user_ids => [@logged_in_user.id] + (@logged_in_user.follower_ids or []) + mentioned_user_ids,
            :mentioned_user_ids => mentioned_user_ids,
            :created_at => Time.now,
            :content => params["content"]
        })
        post.save

        mentioned_users.each{ |u|
            if not u.mention_post_ids
                u.mention_post_ids = []
                u.num_mentions = 0
            end
            u.mention_post_ids << post.id
            u.num_mentions += 1
            u.save
        }

        redirect "/home/"
    else
        redirect "/login/"
    end
end

post "/emission/:post_id/update/?" do |post_id|
    redirect "/emission/#{post_id}/"
end

get "/search/?" do
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

#load the routes for each module's functionality
