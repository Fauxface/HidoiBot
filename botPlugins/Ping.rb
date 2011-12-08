# Ng Guoyou
# Ping.rb
# Gives a pong reply.

# Common BotPlugin methods can be found in the file "core/BotPlugin.rb"
# This includes:
#    escapeSyntax(string), escapeSyntaxHard(string)
#    handleError(error)
#    sayf(string) <= see m.reply, m.replyTo
#    bold(string), italics(string), underline(string)
#    colour(string, textColour, highlightColour), reverseColour(string)
#    decimalPlace(int, places)
#    humaniseSeconds(integer)
#    loadSettings(file), saveSettings(file)

# Timer methods can be found in "/core/Timer.rb"
# SQLite implementation can be found in "/core/HidoiSQL.rb"
# Message implementation can be found in "/core/Message.rb"

# For an example of how to implement threading, see MpcSync.rb
# For an example of how to make a plugin process every message and use HidoiSQL, see "ImageScraper.rb"
# For a template, see "inactive/Template.rb"

# Filename must be the same as class name ie. Ping.rb for class Ping
# You can have multiple classes in a file, but only the class with the same name as the filename will be accessible publicly

class Ping < BotPlugin
  # Include any requires or related here, eg. "require 'openssl'"

  # initialize is required for all bot plugins.
  def initialize
    # Name: required, leave as it is
    name = self.class.name

    # Hook: nil if there is no trigger, ie. "hook = nil"
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

  # main(m) required for every plugin, the bot will call main(m) when triggered
  def main(m)
    # m is a Message containing information on a particular line sent to the bot
    # For more info, see /core/Message.rb
    #
    # To use m:
    #   m.attribute OR
    #   m.method
    #
    # Attributes:
    #   *sender
    #   *realname
    #   *hostname
    #   *messageType
    #   *channel
    #   *message
    #   *rawMessage
    #   *authLevel
    #   *time
    #   *serverGroup
    #   *origin
    #   *originId
    #
    # Methods:
    #   *reply
    #   *sayTo(channel, string)
    #   *trigger <= Returns trigger
    #   *stripTrigger <= Returns message with trigger removed
    #   *args <= Returns an array of args with trigger removed
    #   *mode <= Returns args[0]
    #   *auth(reqAuth)
    #   *noAuth
    #   *authR(reqAuth) <= Combines auth and noAuth for convenience
    #   *shiftWords(n)
    #   *truncateWords(n)
    #
    # ---
    #
    # Some useful methods:
    #   Normally you'll use m.reply to make the bot say stuff. m.reply is a method in Message
    #   m.reply(someString)
    #
    #   You can use any method found in class IRC as well:
    #   m.origin.method
    #
    # The bot will eval anything returned, but this should not be necessary.
    # Best to return nil if there is no visible output, ie "return nil"
    #
    # Long strings can be said without issue
    # To make the bot say multiple lines, use "\n" to indicate line breaks

    m.reply(pong(m))

    # Alternatively, do
    # m.reply(someString) if m.authR(requiredLevel)
    # or
    # return sayf(someString)

    return nil
  rescue => e
    # Do this if the plugin breaks
    handleError(e)
    return nil
  end

  # Additional methods can be included
  def pong(m)
    requiredLevel = 3
    if m.auth(requiredLevel)
      # User's auth level is sufficient
      return "pong~"
    else
      return "pong"
    end
  end
end