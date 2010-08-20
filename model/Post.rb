class Post
    include MongoMapper::Document

    key :author_id, :index => true      # the user id of the guy who posted this
    key :author_username, String
    key :author_pretty_name, String
    key :user_ids, :index => true       # an array of all the user id's whose timeline this belongs in
    key :created_at, Time
    key :content, String

    def self.get_user_timeline(user_id)
        Post.where(:user_ids => user_id).sort(:created_at.desc).all
    end

end
