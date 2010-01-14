
class SessionService

    def initialize(settings, sessionDao)
        @settings = settings
        @sessionDao = sessionDao
    end

    def get(id)
        @sessionDao.get(id)
    end

    def save(session)
        @sessionDao.save(session)
    end

    def delete(session)
        @sessionDao.delete(session)
    end

end
