
=begin
    Load configuration values from a file and access them as if they're in an associative array.
=end
class Settings

=begin
    @param settings - an optional map of config values; anything that is set here will override the defaults
=end
    def initialize(settings={})
        # set the default configuration values
        @settings = {
            "api_version" => "0.0.1a",
            "db_name" => "ot2",
            "timeline" => "localhost:4567",
        }
        # override any of the default values with the ones in the given settings hash
        settings.keys.each{ |key|
            @settings[key] = settings[key]
        }
    end

=begin
    @param filename - the path to a file with the config values in it, which will be parsed and used to define the settings
    @return a Settings object instantiated with all default values set and possibly overriden by the values in the (optionally) given filename
=end
    def self.load(filename=nil)
        if not filename
            Settings.new
        else
            # TODO: actually parse a file!
            Settings.new({})
        end
    end

=begin
    @param key - the key into the settings map
    @return the value stored for the given key, or nil if the key doesn't exist
=end
    def [](key)
        @settings[key]
    end

end
