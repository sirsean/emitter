
=begin
    A service to receive server-to-server communication from another timeline server.
=end
class ServerService

    def initialize(settings, userDao, tweetDao)
        @settings = settings
        @userDao = userDao
        @tweetDao = tweetDao
    end

=begin
    Get the version of the API that's running here.
=end
    def getApiVersion(payload)
        {"version" => @settings["api_version"]}
    end

=begin
    A user on another timeline server has followed a user on this timeline server. Here, we update the "followers" list so that we can keep track of the number of followers across timeline servers.

    @param username
    @param follower - {username, timeline}
=end
    def forwardFollow(username, follower)
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

    @param username
    @param follower - {username, timeline}
=end
    def forwardUnfollow(username, follower)
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
    Accept a forwarded emission from another timeline.

    @param usernames - a list of usernames to put an emission into their timelines
    @param emission
=end
    def forwardEmit(usernames, emission)
        if @settings["standalone"] and (emission["timeline"] != @settings["timeline"])
            return {"status" => "fail", "error" => "Can't follow across timelines in standalone mode"}
        end

        # save the remote id so we know what id the emission is on the remote server that sent this to us
        emission["remote_id"] = emission['_id']
        emission.delete('_id')
        emission["local_posted_date"] = Time.now()

        @tweetDao.save(emission)

        usernames.each { |username|
            user = @userDao.getByUsername(username)
            if user and @userDao.isFollowing(username, {"username"=>emission["username"], "timeline"=>emission["timeline"]})
                if not user["timeline"]
                    user["timeline"] = []
                end
                user["timeline"] = user["timeline"].insert(0, emission[:_id])
                @userDao.save(user)
            end
        }
    end

end
