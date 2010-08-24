class Conversation
    include MongoMapper::Document

    key :post_ids, :index => true
    key :user_ids, :index => true
    key :created_at

    def add_user(user_id)
        @user_ids.push(user_id).uniq!
    end

    def remove_user(user_id)
        @user_ids.delete(user_id)
    end
end
