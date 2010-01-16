
=begin
    A service whose methods require no authentication.
=end
class PublicService

    def initialize(settings, userDao, tweetDao)
        @settings = settings
        @userDao = userDao
        @tweetDao = tweetDao
    end

=begin
    Create a new user.

    @param user - {"username", "password", "email", "pretty_name"}
=end
    def createUser(user)
        username = user['username']
        password = user['password']
        email = user['email']
        pretty_name = user['pretty_name']

        if not username or not password or not email or not pretty_name
            raise "Illegal argument: missing parameter"
        end

        # check if the user already exists
        existing = @userDao.getByUsername(username)
        if existing
            raise "Illegal argument: username already exists"
        end

        # create the user
        saved = {
            "username" => username,
            "password" => password,
            "email" => email,
            "pretty_name" => pretty_name
        }

        @userDao.save(saved)

        saved
    end

=begin
    Get a user's information.

    @param username
    @return basic user information
=end
    def getUserInfo(username)
        user = @userDao.getByUsername(username)
        if not user
            raise "User not found"
        end

        {
            "username" => user["username"],
            "email" => user["email"],
            "pretty_name" => user["pretty_name"]
        }
    end

=begin
    Get the users that a user is following.

    @param username
    @return a list of user hashes of the users the given user is following
=end
    def getFollowing(username)
        if not username
            raise "Illegal argument: missing username"
        end

        user = @userDao.getByUsername(username)
        if not user
            raise "User not found"
        end

        if not user["following"]
            user["following"] = []
        end

        user["following"]
    end

=begin
    Get the users that are following a user.

    @param username
    @return a list of user hashes of the users that are following the given user
=end
    def getFollowers(username)
        if not username
            raise "Illegal argument: missing username"
        end

        user = @userDao.getByUsername(username)
        if not user
            raise "User not found"
        end

        if not user["followers"]
            user["followers"] = []
        end

        user["followers"]
    end

=begin
    Get a user's emissions. You can let it give you just the most recent ones, or limit it by date ranges if you want.

    @param username
    @param after_date (optional) - limit it to emissions after this date
    @param before_date (optional) - limit it to emissions before this date
    @return a list of emission hashes
=end
    def getEmissions(username, after_date=nil, before_date=nil)
        if not username
            raise "Illegal argument: missing username"
        end

        if after_date and not after_date.empty?
            after_date = Time.parse(after_date)
        end
        if before_date and not before_date.empty?
            before_date = Time.parse(before_date)
        end

        user = @userDao.getByUsername(username)
        if not user
            raise "User not found"
        end

        tweets = @tweetDao.getTweets(user['tweets'])

        # need to call map because the DAO returns a Mongo Cursor, which is iterable but is not an array
        tweets.map{ |tweet|
            tweet
        }
    end

end
