class Post
    include MongoMapper::Document

    key :author_id, :index => true      # the user id of the guy who posted this
    key :author_username, String
    key :author_pretty_name, String
    key :user_ids, :index => true       # an array of all the user id's whose timeline this belongs in
    key :mentioned_user_ids, :index => true     # an array of all the user id's who were mentioned in this post
    key :in_reply_to_post_id
    key :conversation_id
    key :created_at, Time
    key :content, String

    def self.get_user_timeline(user_id)
        Post.where(:user_ids => user_id).sort(:created_at.desc).all
    end

    def self.get_by_mentioned_user_id(user_id)
        Post.where(:mentioned_user_ids => user_id).sort(:created_at.desc).all
    end

    def self.get_by_author_id(user_id)
        Post.where(:author_id => user_id).sort(:created_at.desc).all
    end

    def self.get_by_post_ids(post_ids)
        Post.where(:id => post_ids).sort(:created_at.desc).all
    end

    def self.search_content(term)
        Post.where(:content => /#{term.downcase}/i).sort(:created_at.desc).all
    end

end
