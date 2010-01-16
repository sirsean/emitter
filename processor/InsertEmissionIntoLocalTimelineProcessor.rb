
class InsertEmissionIntoLocalTimelineProcessor

    def initialize(settings, userDao)
        @settings = settings
        @userDao = userDao
    end

=begin
    Insert an emission into the timeline of all its author's followers.
    
    This only operates on the _local timeline_, so it throws out any followers on a remote timeline.

    @param user - the user that posted the emission (with his list of followers)
    @param emission - the emission that was posted
=end
    def process(user, emission)
        if user["followers"]
            user["followers"].find_all{ |follower| 
                follower["timeline"] == @settings["timeline"] 
            }.find_all{ |follower|
                @userDao.isFollowing(follower["username"], {"username"=>user["username"], "timeline"=>user["timeline"]})
            }.each{ |follower|
                localUser = @userDao.getByUsername(follower["username"])
                if localUser
                    if not localUser["timeline"]
                        localUser["timeline"] = []
                    end
                    localUser["timeline"].insert(0, emission[:_id])
                    @userDao.save(localUser)
                end
            }
        end
    end

end
                
