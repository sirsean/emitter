
=begin
    A service to receive server-to-server communication from another timeline server.
=end
class ServerService

    def initialize(settings, userDao, tweetDao)
        @settings = settings
        @userDao = userDao
        @tweetDao = tweetDao
    end

    def getApiVersion(payload)
        {"version" => @settings["api_version"]}
    end

=begin
    A user on another timeline server has followed a user on this timeline server. Here, we update the "followers" list so that we can keep track of the number of followers across timeline servers.

    Expects:
    {
        "method": "forwardFollow",
        "username": username,
        "follower": {
            "username": username,
            "timeline": timeline
        }
    }

=end
    def forwardFollow(payload)
        username = payload['username']
        follower = payload['follower']

        if not username or not follower or not follower["username"] or not follower["timeline"]
            raise "Illegal argument: missing parameter"
        end

        if @settings["standalone"] and (follower["timeline"] != @settings["timeline"])
            return {"status" => "fail", "error" => "Can't follow across timelines in standalone mode"}
        end

        user = @userDao.getByUsername(username)
        if not user
            raise "User not found"
        end

        if not user["followers"]
            user["followers"] = []
        end

        user["followers"].push(follower)

        @userDao.save(user)

        {"status"=>"success"}
    end

=begin
    A user on another timeline server has followed a user on this timeline server. Here, we update the "followers" list so that we can keep track of the number of followers across timeline servers.

    Expects:
    {
        "method": "forwardUnfollow",
        "username": username,
        "follower": {
            "username": username,
            "timeline": timeline
        }
    }

=end
    def forwardUnfollow(payload)
        username = payload['username']
        follower = payload['follower']

        if not username or not follower or not follower['username'] or not follower['timeline']
            raise "Illegal argument: missing parameter"
        end

        if @settings["standalone"] and (follower["timeline"] != @settings["timeline"])
            return {"status" => "fail", "error" => "Can't follow across timelines in standalone mode"}
        end

        user = @userDao.getByUsername(username)
        if not user
            raise "User not found"
        end

        if not user["followers"]
            user["followers"] = []
        end

        user["followers"].delete(follower)

        @userDao.save(user)

        {"status"=>"success"}
    end

=begin
    Expects:
    {
        "method": "forwardPostTweet",
        "usernames": usernames,
        "tweet": tweet (the _id field should not be set)
    }
=end
    def forwardPostTweet(payload)
        usernames = payload["usernames"]
        tweet = payload["tweet"]

        if @settings["standalone"] and (tweet["timeline"] != @settings["timeline"])
            return {"status" => "fail", "error" => "Can't follow across timelines in standalone mode"}
        end

        # save the remote id so we know what id the tweet is on the remote server that sent this to us
        tweet["remote_id"] = tweet['_id']
        tweet.delete('_id')
        tweet["local_posted_date"] = Time.now()

        @tweetDao.save(tweet)

        usernames.each { |username|
            user = @userDao.getByUsername(username)
            if user and @userDao.isFollowing(username, {"username"=>tweet["username"], "timeline"=>tweet["timeline"]})
                if not user["timeline"]
                    user["timeline"] = []
                end
                user["timeline"] = user["timeline"].insert(0, tweet[:_id])
                @userDao.save(user)
            end
        }
    end

end
