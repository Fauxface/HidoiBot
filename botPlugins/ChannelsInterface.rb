# Ng Guoyou
# ChannelsInterface.rb
# This plugin provides an interface for joining/parting channels and changing of nicknames.

class ChannelsInterface < BotPlugin
  def initialize
    # Authorisations
    @reqAuthLevel = 3

    # Required plugin stuff
    name = self.class.name
    hook = ["join", "part", "nick"]
    processEvery = false
    help = "Usage: #{hook} <term>\nFunction: Joins/parts a channel or changes the bot's nickname."
    super(name, hook, processEvery, help)
  end

  def main(m)
    if m.authR(@reqAuthLevel)
      channel = m.args[0]

      case m.trigger
      when 'join'
        m.origin.joinChannel(channel)
      when 'part'
        m.origin.partChannel(channel)
      when 'nick'
        m.origin.send("NICK #{channel}")
      end
    end
    
    return nil
  rescue => e
    handleError(e)
    return nil
  end
end