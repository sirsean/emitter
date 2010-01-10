
=begin
    A service whose methods require no authentication.
=end
class PublicService

    def initialize(settings, userDao, tweetDao)
        @settings = settings
        @userDao = userDao
        @tweetDao = tweetDao
    end

    # Expects the following:
    # {
    #   "method": "createUser",
    #   "user": {
    #       "username": username,
    #       "password": password,
    #       "email": email,
    #       "pretty_name": pretty_name
    #   }
    # }
    def createUser(payload)
        username = payload['user']['username']
        password = payload['user']['password']
        email = payload['user']['email']
        pretty_name = payload['user']['pretty_name']

        if not username or not password or not email or not pretty_name
            raise "Illegal argument: missing parameter"
        end

        # check if the user already exists
        user = @userDao.getByUsername(username)
        if user
            raise "Illegal argument: username already exists"
        end

        # create the user
        user = {
            "username" => username,
            "password" => password,
            "email" => email,
            "pretty_name" => pretty_name
        }

        @userDao.save(user)

        user
    end

=begin
    Get a user's information.

    Expects:
    {
        "method": "getUserInfo",
        "username": username
    }
=end
    def getUserInfo(payload)
        username = payload['username']

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

    Expects:
    {
        "method": "getFollowing",
        "username": username
    }
=end
    def getFollowing(payload)
        username = payload["username"]

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

    Expects:
    {
        "method": "getFollowers",
        "username": username
    }
=end
    def getFollowers(payload)
        username = payload["username"]

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
    Get a user's tweets. You can let it give you just the most recent ones, or limit it by date ranges if you want.

    Expects:
    {
        "method": "getTweets",
        "username": username,
        "after_date": afterDate, (optional)
        "before_date": beforeDate (optional)
    }
=end
    def getTweets(payload)
        username = payload['username']

        if not username
            raise "Illegal argument: missing username"
        end

        if payload["after_date"]
            afterDate = DateTime.parse(payload["after_date"])
        end
        if payload["before_date"]
            beforeDate = DateTime.parse(payload["before_date"])
        end

        user = @userDao.getByUsername(username)
        if not user
            raise "User not found"
        end

        if user["tweets"] and user["tweets"].length > 0
            tweets = @tweetDao.getTweets(user['tweets'])
        else
            tweets = []
        end

        # need to call map because the DAO returns a Mongo Cursor, which is iterable but is not an array
        tweets.map{ |tweet|
            tweet
        }
    end

end
