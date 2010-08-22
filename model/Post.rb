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

    # use this method to create a new Post and handle all the mentions, timelines, conversations, etc that go along with it
    # required parameters: :author (User object), :content
    # optional parameters: :in_reply_to
    def self.emit(params)
        # get the author
        author = params[:author]

        # determine all mentions in this post
        mentioned_usernames = params[:content].extract_usernames
        mentioned_users = User.get_by_usernames(mentioned_usernames)
        mentioned_user_ids = mentioned_users.map{|u| u.id}

        # calculate the in_reply_to/conversation
        in_reply_to = Post.find(params[:in_reply_to])
        conversation = nil
        conversation_id = nil
        if not in_reply_to.nil?
            in_reply_to_post_id = in_reply_to.id
            if in_reply_to.conversation_id
                conversation = Conversation.find(in_reply_to.conversation_id)
            else
                conversation = Conversation.create({
                    :post_ids => [in_reply_to.id],
                    :user_ids => [in_reply_to.author_id],
                    :created_at => Time.now
                })
                in_reply_to.conversation_id = conversation.id
                in_reply_to.save
            end
            conversation_id = conversation.id
        end

        # determine which users have this post in their timeline
        timeline_user_ids = [author.id]
        if author.follower_ids
            timeline_user_ids += author.follower_ids
        end
        if mentioned_user_ids
            timeline_user_ids += mentioned_user_ids
        end
        if conversation and conversation.user_ids
            timeline_user_ids += conversation.user_ids
        end
        timeline_user_ids.uniq!

        # create the post
        post = Post.create({
            :author_id => author.id,
            :author_username => author.username,
            :author_pretty_name => author.pretty_name,
            :content => params[:content],
            :created_at => Time.now,
            :user_ids => timeline_user_ids,
            :mentioned_user_ids => mentioned_user_ids,
            :in_reply_to_post_id => in_reply_to_post_id,
            :conversation_id => conversation_id
        })
        post.save

        # update the conversation with this new post
        if conversation
            conversation.post_ids << post.id
            conversation.user_ids << post.author_id

            conversation.post_ids.uniq!
            conversation.user_ids.uniq!

            conversation.save
        end

        # update all the mentioned users
        mentioned_users.each do |mentioned_user|
            if not mentioned_user.mention_post_ids
                mentioned_user.mention_post_ids = []
                mentioned_user.num_mentions = 0
            end
            mentioned_user.mention_post_ids << post.id
            mentioned_user.num_mentions += 1
            mentioned_user.save
        end

        return post
    end

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
