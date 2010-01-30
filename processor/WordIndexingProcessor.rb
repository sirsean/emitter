
class WordIndexingProcessor

    def initialize(settings, tweetDao)
        @settings = settings
        @tweetDao = tweetDao
    end

=begin
    Take the content of this tweet and index all the words in it.

    @param user - the user that posted the emission
    @param emission - the emission that was posted
=end
    def process(user, emission)
        emission["words"] = (emission["metadata"]["content"]).split.uniq.map{|e| e.downcase}
        @tweetDao.save(emission)
    end

end
