# Ng Guoyou
# ChannelsInterface.rb
# This plugin provides an interface for joining/parting channels and changing of nicknames.

class ChannelsInterface < BotPlugin
  def initialize
    # Authorisations
    @reqAuthLevel = 3

    # Strings
    @noAuthMsg = 'You are not authorised for this.'

    # Required plugin stuff
    name = self.class.name
    hook = ["join", "part", "nick"]
    processEvery = false
    help = "Usage: #{hook} <term>\nFunction: Joins/parts a channel or changes the bot's nickname."
    super(name, hook, processEvery, help)
  end

  def main(data)
    @givenLevel = data["authLevel"]

    if authCheck(@reqAuthLevel)
      mode = data["trigger"]
      channel = arguments(data)[0]

      case mode
      when 'join'
        return "joinChannel('#{channel}')"
      when 'part'
        return "partChannel('#{channel}')"
      when 'nick'
        return "send 'NICK #{channel}'"
      end
    else
      return sayf(@noAuthMsg)
    end
  rescue => e
    handleError(e)
    return nil
  end
end