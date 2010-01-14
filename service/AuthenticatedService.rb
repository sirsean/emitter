
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

    Expects:
    {
        "method": "authenticate",
        "username": username,
        "password": password
    }
=end
    def authenticate(payload)
        username = payload["username"]
        password = payload["password"]

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

    Expects:
    {
        "method": "saveUserInfo",
        "username": username,
        "user": {
            "username": username,
            "password": password,
            "email": email,
            "pretty_name": pretty_name
        }
    }
=end
    def saveUserInfo(payload)
        username = payload["username"]
        info = payload["user"]

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
    Expects:
    {
        "method": "follow",
        "username": username,
        "to_follow": {
            "username": username,
            "timeline": timeline
        }
    }
=end
    def follow(payload)
        username = payload['username']
        toFollow = payload['to_follow']

        if not username or not toFollow or not toFollow['username'] or not toFollow['timeline']
            raise "Illegal Argument: missing parameter"
        end

        user = @userDao.getByUsername(username)
        if not user
            raise "User not found"
        end

        # determine if the user is already following the given user
        if @userDao.isFollowing(username, toFollow)
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
    Expects:
    {
        "method": "unfollow",
        "username": username,
        "to_unfollow": {
            "username": username,
            "timeline": timeline
        }
    }
=end
    def unfollow(payload)
        username = payload['username']
        toUnfollow = payload['to_unfollow']

        if not username or not toUnfollow or not toUnfollow['username'] or not toUnfollow['timeline']
            raise "Illegal Argument: missing parameter"
        end

        user = @userDao.getByUsername(username)
        if not user
            raise "User not found"
        end

        # determine if the user is currently following the given user
        if not @userDao.isFollowing(username, toUnfollow)
            raise "Not following that user"
        end

        # this should never happen, but let's just be safe, shall we?
        if not user["following"]
            user["following"] = []
        end

        user["following"].delete(toUnfollow)

        @userDao.save(user)

        # forward on to the server service
        @unfollowProcessors.each{ |processor|
            processor.process(username, toUnfollow)
        }

        {"status"=>"success"}
    end

=begin
    Post a tweet to your timeline.
    Expects:
    {
        "method": "postTweet",
        "username": username,
        "metadata": metadata (object)
    }
=end
    def postTweet(payload)
        username = payload["username"]
        metadata = payload["metadata"]
        
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

    Expects:
    {
        "method": "getTimeline",
        "username": username,
        "before_date": before_date (optional),
        "after_date": after_date (optional)
    }
=end
    def getTimeline(payload)
        username = payload['username']
        before_date = payload['before_date']
        after_date = payload['after_date']

        if not username
            raise "Illegal argument: missing parameter"
        end

        user = @userDao.getByUsername(username)
        if not user
            raise "User not found"
        end

        if not user['timeline']
            user['timeline'] = []
        end

        tweets = @tweetDao.getTweets(user['timeline'], before_date, after_date)

        if not before_date or not after_date
            tweets = tweets.map{|t| t}[0..24]
        end

        # we need to call map because the DAO returns a Mongo Cursor object, which is an iterator but is not an array
        tweets.map{|t| t}
    end

end
