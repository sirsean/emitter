
=begin
    A service whose methods require a user to be authenticated.
=end
class AuthenticatedService

    def initialize(settings, userDao, tweetDao, postTweetProcessors=[], followProcessors=[], unfollowProcessors=[])
        @settings = settings
        @userDao = userDao
        @tweetDao = tweetDao
        @postTweetProcessors = postTweetProcessors
        @followProcessors = followProcessors
        @unfollowProcessors = unfollowProcessors
    end

=begin
    Authenticate a user and return the user info object.

    @param username
    @param password
    @return the user matching the given username/password, if any
=end
    def authenticate(username, password)
        if not username or not password
            raise "Illegal argument: missing parameter"
        end

        user = @userDao.getByUsername(username)
        if not user
            raise "User not found"
        end

        if user["password"] != password
            raise "Invalid password"
        end

        # the authentication was successful, return the user object
        user
    end

=begin
    Save the user info for an existing user.

    @param username
    @param info - {username, password, email, pretty_name}
=end
    def saveUserInfo(username, info)
        if not username or not info or not info["username"] or not info["password"] or not info["email"] or not info["pretty_name"]
            raise "Illegal argument: missing parameter"
        end

        if username != info["username"]
            raise "Illegal argument: Cannot change the username"
        end

        user = @userDao.getByUsername(username)
        if not user
            raise "User not found"
        end

        user["password"] = info["password"]
        user["email"] = info["email"]
        user["pretty_name"] = info["pretty_name"]

        @userDao.save(user)

        {"status" => "success"}
    end

=begin
    Follow another user (possibly on a different timeline)

    @param username
    @param to_follow - {username, timeline}
=end
    def follow(username, to_follow)
        if not username or not to_follow or not to_follow['username'] or not to_follow['timeline']
            raise "Illegal Argument: missing parameter"
        end

        user = @userDao.getByUsername(username)
        if not user
            raise "User not found"
        end

        # determine if the user is already following the given user
        if @userDao.isFollowing(username, to_follow)
            raise "Already following that user!"
        end

        if not user["following"]
            user["following"] = []
        end

        user["following"].push(toFollow)

        @userDao.save(user)

        @followProcessors.each{ |processor|
            processor.process(username, toFollow)
        }

        {"status"=>"success"}
    end

=begin
    Follow another user (possibly on a different timeline)

    @param username
    @param to_unfollow - {username, timeline}
=end
    def unfollow(username, to_unfollow)
        if not username or not to_unfollow or not to_unfollow['username'] or not to_unfollow['timeline']
            raise "Illegal Argument: missing parameter"
        end

        user = @userDao.getByUsername(username)
        if not user
            raise "User not found"
        end

        # determine if the user is currently following the given user
        if not @userDao.isFollowing(username, to_unfollow)
            raise "Not following that user"
        end

        # this should never happen, but let's just be safe, shall we?
        if not user["following"]
            user["following"] = []
        end

        user["following"].delete(to_unfollow)

        @userDao.save(user)

        # forward on to the server service
        @unfollowProcessors.each{ |processor|
            processor.process(username, toUnfollow)
        }

        {"status"=>"success"}
    end

=begin
    Post an emission to your timeline.

    @param username
    @param metadata
=end
    def emit(username, metadata)
        if not username or not metadata
            raise "Illegal Argument: missing parameter"
        end

        user = @userDao.getByUsername(username)
        if not user
            raise "User not found"
        end

        if not user["tweets"]
            user["tweets"] = []
        end
        if not user["timeline"]
            user["timeline"] = []
        end

        tweet = {
            "username" => username,
            "timeline" => @settings['timeline'],
            "posted_date" => Time.now(),
            "metadata" => metadata
        }

        @tweetDao.save(tweet)

        user["tweets"] = user["tweets"].insert(0, tweet[:_id])
        user["timeline"] = user["timeline"].insert(0, tweet[:_id])

        @userDao.save(user)

        # run the post-tweet processors
        @postTweetProcessors.each{ |processor|
            processor.process(user, tweet)
        }

        {"status"=>"success"}
    end

=begin
    Get the tweets in a user's timeline. If they specify two dates, we'll return _everything_ in that date range, but if they specify either one or zero dates, we limit the response to 25 tweets.

    @param username
    @param after_date (optional) - limit it to emissions after this date
    @param before_date (optional) - limit it to emissions before this date
=end
    def getTimeline(username, after_date=nil, before_date=nil)
        if not username
            raise "Illegal argument: missing parameter"
        end

        user = @userDao.getByUsername(username)
        if not user
            raise "User not found"
        end

        if after_date and not after_date.empty?
            after_date = Time.parse(after_date)
        end
        if before_date and not before_date.empty?
            before_date = Time.parse(before_date)
        end

        if not user['timeline']
            user['timeline'] = []
        end

        tweets = @tweetDao.getTweets(user['timeline'], before_date, after_date)

        if not before_date and not after_date
            tweets = tweets.map{|t| t}[0..24]
        end

        # we need to call map because the DAO returns a Mongo Cursor object, which is an iterator but is not an array
        tweets.map{|t| t}
    end

end
