
=begin
    A post-processor for when a user posts a tweet.

    This will forward the tweet to remote timeline servers.
=end
class ForwardTweetProcessor

    def initialize(settings, remoteServerService)
        @settings = settings
        @remoteServerService = remoteServerService
    end

=begin
    Build a follower-map and forward it to the timeline servers of all the author's followers.

    @param user - the user that posted a tweet (with his list of followers)
    @param tweet - the tweet that was posted
=end
    def process(user, tweet)
        followerMap = {}
        if user["followers"]
            user["followers"].each { |follower|
                if not followerMap[follower["timeline"]]
                    followerMap[follower["timeline"]] = []
                end
                followerMap[follower["timeline"]] << follower["username"]
            }
            @remoteServerService.forwardPostTweet(followerMap, tweet)
        end
    end

end
