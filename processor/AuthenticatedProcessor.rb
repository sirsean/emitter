
=begin
    A pre-processor to authenticate a service call.
=end
class AuthenticatedProcessor

    def initialize(settings, userDao)
        @settings = settings
        @userDao = userDao
    end

=begin
    Authenticate a user based on the username and password set in the payload object.

    @param payload - the payload object being passed in; if it doesn't have both username and password set, it will not authenticate
    @raise an AuthenticationError if the username/password pair doesn't match anything in the database
=end
    def process(payload)
        if not payload["username"] or not payload["password"]
            raise "Authentication error: Missing username/password"
        end

        if not @userDao.authenticateUser(payload["username"], payload["password"])
            raise "Authentication error: Invalid login"
        end
    end
end

