# Common BotPlugin methods can be found in the file "core/BotPlugin.rb"
# This includes:
#    authCheck(requiredLevel integer)
#    arguments(data)
#    stripTrigger(data)
#    detectMode(data)
#    escapeSyntax(string)
#    handleError(error)
#    sayf(string)
#    bold(string)
#    humaniseSeconds(seconds integer)

# Timer methods can be found in "core/Timer.rb"
# SQLite implementation can be found in "core/HidoiSQL.rb"

# For an example of how to implement threading, see MpcSync.rb
# For an example of how to make a plugin process every message and use HidoiSQL, see "ImageScraper.rb"
# For a template, see "inactive/Template.rb"

# Filename must be the same as class name
# You can have multiple classes in a file, but only the class with the same name as the filename will be properly accessable from IRC
class Ping < BotPlugin
    # Include any requires or related here, eg "require 'openssl'"
        
    # initialize is required for all bot plugins.
    def initialize
        # Name: required, leave as it is
        name = self.class.name
    
        # Hook: nil if there is no trigger, ie "hook = nil"
        #
        # Single hook:
        # hook = "ping"
        #
        # Multiple hooks:
        hook = ["ping", "dicks"]
        
        # ProcessEvery: true|false - Is every PRIVMSG passed to this plugin?
        processEvery = false
        
        # Help: what is returned on ~help Ping
        help = "Usage: #{hook}\nFunction: Dicks: DICKERY DICKS DICKS DICKS DICKS"
                
        # Register plugin, do mapping, help is optional, but why not just stuff something in there?
        super(name, hook, processEvery, help)
        
        # If you want to *hack* in additional hooks the wrong way:
        # This isn't tested or supported
        # hook2 = 'peng'
        # super(name, hook2, processEvery, help)
    end
    
    # main(data) required for every plugin, the bot will call main(data) when triggered
    def main(data)
        # data is a Hash containing information on a particular line sent to the bot
        #
        # To use data:
        #   data["<detail>"]
        #
        # Detail types:
        #   "sender"
        #   "realname"
        #   "hostname"
        #   "messageType"
        #   "channel"
        #   "message"
        #   "authLevel"
        #   "trigger"
        
        # @givenLevel is required if authCheck is used. Better to just leave it in.
        @givenLevel = data["authLevel"]
        
        # return string is going to be eval()-ed by IRC class
        #
        # Some useful methods:
        #   Normally you'll use sayf to make the bot say stuff. sayf is a common BotPlugin method.
        #    sayf("someString")
        #
        #   You can use any method found in class IRC as well:
        #    "sayTo '#{channel}, #{variable}'"
        # 
        # Best to return nil if there is no visible output, ie "return nil"
        # Long strings can be said without issue
        # To make the bot say multiple lines, use "\n" to indicate line breaks
        
        return sayf(pong())
    rescue => e
        # Do this if the plugin breaks
        handleError(e)
        return nil
    end
    
    # Additional methods can be included
    def pong
        requiredLevel = 2

        if authCheck(requiredLevel)
            # User's auth level is sufficient
            return "pong~"
        else
            return "pong"            
        end
    end
end