=begin
    A post-processor for when a user follows another user.

    This will forward this follow-action to remote timeline servers so they can also keep track of the users' relationship.
=end
class ForwardFollowProcessor

    def initialize(settings, remoteServerService)
        @settings = settings
        @remoteServerService = remoteServerService
    end

=begin
    @param username - the username of the local user that is following someone
    @param toFollow - the username/timeline pair of a remote user who is being followed
=end
    def process(username, toFollow)
        @remoteServerService.forwardFollow(toFollow["timeline"], toFollow["username"], {"username"=>username, "timeline"=>@settings["timeline"]})
    end

end
