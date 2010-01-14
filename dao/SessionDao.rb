
=begin
    A DAO to access sessions.
=end
class SessionDao

    def initialize(sessionCollection)
        @sessionCollection = sessionCollection
    end

    def save(session)
        @sessionCollection.save(session)
    end

    def get(id)
        @sessionCollection.find_one('_id' => id)
    end

    def delete(session)
        @sessionCollection.remove(session)
    end
end

