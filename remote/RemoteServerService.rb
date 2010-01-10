require 'net/http'
require 'uri'
require 'json'

=begin
    A helper server that sends actions to the ServerService on a remote timeline server.
=end
class RemoteServerService

=begin
    When someone on our timeline server follows someone on another timeline server, we need to forward that follow-action on to the other timeline server so they can keep track of who is following their user.

    @param remoteTimeline - the host/port of the remote timeline server
    @param username - the username on the remote timeline server who is being followed
    @param follower - the username/timeline pair of the user on the local timeline server who is doing the following
=end
    def forwardFollow(remoteTimeline, username, follower)
        request = {
            "method" => "forwardFollow",
            "username" => username,
            "follower" => follower
        }

        result = Net::HTTP.post_form(URI.parse("http://#{remoteTimeline}/api/"), {"payload" => JSON.generate(request)})

        JSON.parse(result.body)
    end

=begin
    When someone on our timeline server unfollows someone on another timeline server, we need to forward that unfollow-action on to the other timeline server so they can keep track of who is following their user.

    @param remoteTimeline - the host/port of the remote timeline server
    @param username - the username on the remote timeline server who was being followed and no longer is
    @param follower - the local username/timeline pair who is unfollowing the remote user
=end
    def forwardUnfollow(remoteTimeline, username, follower)
        request = {
            "method" => "forwardUnfollow",
            "username" => username,
            "follower" => follower
        }

        result = Net::HTTP.post_form(URI.parse("http://#{remoteTimeline}/api/"), {"payload" => JSON.generate(request)})

        JSON.parse(result.body)
    end

=begin
    When someone on our timeline server posts a tweet, we need to forward it along to the timeline server of all the tweeting user's followers.

    @param followerMap - a timeline->list-of-usernames map
    @param tweet - the tweet to forward to the other timeline servers
=end
    def forwardPostTweet(followerMap, tweet)
        puts followerMap.inspect
        followerMap.keys().each { |timeline|
            request = {
                "method" => "forwardPostTweet",
                "usernames" => followerMap[timeline],
                "tweet" => tweet
            }
            result = Net::HTTP.post_form(URI.parse("http://#{timeline}/api/"), {"payload" => JSON.generate(request)})
        }

        {"status"=>"success"}
    end

end
