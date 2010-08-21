class User
    include MongoMapper::Document

    key :username, String, :index => true
    key :password, String
    key :pretty_name, String
    key :email, String
    key :bio, String
    key :follower_ids, :index => true
    key :following_ids, :index => true
    key :mention_post_ids, :index => true
    key :num_followers, Integer
    key :num_following, Integer
    key :num_mentions, Integer

    def self.username_exists?(username)
        User.all(:username => username).count > 0
    end

    def self.get_by_username(username)
        User.all(:username => username).first
    end

    def self.get_by_username_and_password(username, password)
        User.all(:username => username, :password => password).first
    end

    def self.get_by_user_ids(user_ids)
        User.where(:id => user_ids).all
    end

    def self.get_by_usernames(usernames)
        User.where(:username => usernames).all
    end

    def is_following?(user_id)
        if not self.following_ids
            return false
        else
            return self.following_ids.include?(user_id)
        end
    end

    def is_follower?(user_id)
        if not self.follower_ids
            return false
        else
            return self.follower_ids.include?(user_id)
        end
    end
    
end
