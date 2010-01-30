
class BaseDao

    def initialize(collection)
        @collection = collection
    end

    def save(item)
        @collection.save(item)
    end

    def get(id)
        if id.instance_of?(String)
            id = Mongo::ObjectID.from_string(id)
        end
        @collection.find_one('_id' => id)
    end

    def delete(item)
        @collection.remove(item)
    end

end
