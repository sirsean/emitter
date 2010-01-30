
class ConversationProcessor

    def initialize(settings, tweetDao, conversationDao)
        @settings = settings
        @tweetDao = tweetDao
        @conversationDao = conversationDao
    end

=begin
    Manage the conversation an emission is attached to

    If the emission is not in reply to anything, do nothing
    If it's in reply to an emission that doesn't have a conversation yet, create a new conversation and attach it to both emissions
    If it's in reply to an emission that already has a conversation, just attach this emission to that conversation
=end
    def process(user, emission)
        puts "processing conversation"
        if emission["metadata"]["in_reply_to"]
            puts emission["metadata"]["in_reply_to"]
            original = @tweetDao.get(emission["metadata"]["in_reply_to"])
            if original
                puts "got the original"
                puts original["conversation"]
                if original["conversation"]
                    puts "there is a conversation: #{original["conversation"]}"
                    conversation = @conversationDao.get(original["conversation"])

                    conversation["tweets"] << emission[:_id]

                    @conversationDao.save(conversation)

                    emission["conversation"] = original["conversation"]
                    @tweetDao.save(emission)
                else
                    puts "creating a new conversation"
                    conversation = {
                        "original" => original["_id"],
                        "tweets" => [
                            original["_id"],
                            emission[:_id]
                        ]
                    }
                    @conversationDao.save(conversation)
                    puts "conversation id: #{conversation[:_id]}"

                    original["conversation"] = conversation[:_id]
                    emission["conversation"] = conversation[:_id]
                    @tweetDao.save(original)
                    @tweetDao.save(emission)
                end

            end
        end
    end

end
