
=begin
    A DAO to access tweets.
=end
class TweetDao < BaseDao

=begin
    Get a list of tweets based on a list of ids, with an optional date range.

    @param tweet_ids - a list of ids
    @param before_date - all tweets will be before this date (optional)
    @param after_date - all tweets will be after this date (optional)
    @return aa MondoDB Cursor, which can be iterated over
=end
    def getTweets(tweet_ids, before_date=nil, after_date=nil)
        # if there's no list of ids, we'll just return an empty list
        if not tweet_ids
            return []
        end

        query = {
            '_id' => {'$in' => tweet_ids}
        }

        if before_date
            query['posted_date'] = {'$lt' => before_date}
        end
        if after_date
            query['posted_date'] = {'$gt' => after_date}
        end

        @collection.find(query).sort(['posted_date', 'descending'])
    end

    def search(term)
        @collection.find({"words" => /#{term.downcase}/})
    end

end
