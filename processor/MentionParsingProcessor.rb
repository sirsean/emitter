
class MentionParsingProcessor

    def initialize(settings, userDao)
        @settings = settings
        @userDao = userDao
    end

=begin
    Detect mentions and add them to the mentioned users' timelines.

    @param user
    @param emission
=end
    def process(user, emission)
        emission["metadata"]["content"].scan(/@[a-zA-Z0-9\-_]+[a-zA-Z0-9]/).map {
            |u| u.sub("@", "") 
        }.each { |mentioned_username|
            # get the user who was mentioned
            mentioned_user = @userDao.getByUsername(mentioned_username)
            if mentioned_user
                # add the emission to their timeline
                mentioned_user["timeline"].insert(0, emission[:_id])
                mentioned_user["mentions"].insert(0, emission[:_id])

                # save the user
                @userDao.save(mentioned_user)
            end
        }
    end

end
