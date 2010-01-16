
=begin
    A DAO to access users.
=end
class UserDao

    def initialize(userCollection)
        @userCollection = userCollection
    end

=begin
    Get a user by its username.

    @param username
    @return the user that matches that username, or nil if there is no user with that username
=end
    def getByUsername(username)
        users = @userCollection.find("username" => username)
        if users.count() > 0
            user = users.first
            user["timeline"] = [] unless user["timeline"]
            user["tweets"] = [] unless user["tweets"]
            user["followers"] = [] unless user["followers"]
            user["following"] = [] unless user["following"]
            return user
        else
            return nil
        end
    end

=begin
    Authenticate a user with a username and password

    @param username - the username of the user that's logging in
    @param password - the password to check for this user
    @return true if the user is found and the password matches, false otherwise
=end
    def authenticateUser(username, password)
        users = @userCollection.find("username" => username, "password" => password)
        return (users.count() > 0)
    end

=begin
    Determine if a local user is following another user (either local or remote)

    @param username - the username of the local user
    @param toFollow - a username/timeline pair of another user, either on this timeline server or another one
    @return true if the user is following the given user, false if not
=end
    def isFollowing(username, toFollow)
        users = @userCollection.find("username" => username, "following" => {"username"=>toFollow["username"], "timeline"=>toFollow["timeline"]})
        return (users.count() > 0)
    end

=begin
    Persist a user.

    @param user - the user object to save (can be new or existing)
=end
    def save(user)
        @userCollection.save(user)
    end

end
