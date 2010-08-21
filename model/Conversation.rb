class Conversation
    include MongoMapper::Document

    key :post_ids, :index => true
    key :user_ids, :index => true
    key :created_at
end
