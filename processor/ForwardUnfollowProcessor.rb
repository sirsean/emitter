=begin
    A post-processor for when a user unfollows another user.

    This will forward this unfollow-action to remote timeline servers so they can also keep track of the users' relationship.
=end
class ForwardUnfollowProcessor

    def initialize(settings, remoteServerService)
        @settings = settings
        @remoteServerService = remoteServerService
    end

=begin
    @param username - the username of the local user that is unfollowing someone
    @param toUnfollow - the username/timeline pair of a remote user who is being unfollowed
=end
    def process(username, toUnfollow)
        @remoteServerService.forwardUnfollow(toUnfollow["timeline"], toUnfollow["username"], {"username"=>username, "timeline"=>@settings["timeline"]})
    end

end
