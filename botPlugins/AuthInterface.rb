# Ng Guoyou
# AuthInterface.rb
# This plugin provides an interface to HidoiAuth.

class AuthInterface < BotPlugin
  def initialize
    # Required plugin stuff
    name = self.class.name
    @hook = ["auth", "deauth", "checkauth"]
    processEvery = false
    help = "Usage: #{@hook} *<passwordIfAuth-ing> \nFunction: Interfaces with HidoiAuth(tm) ENTERPRISE EDITION"
    super(name, @hook, processEvery, help)
  end

  def main(m)
    case m.trigger
    when @hook[0]
      # Auth
      password = m.args[0]
      m.origin.auth(m)
    when @hook[1]
      # Deauth
      m.origin.deauth(m)
    when @hook[2]
      # Checking auth
      m.reply("You have authorisation level: #{m.authLevel}")
    end

    return nil
  rescue => e
    handleError(e)
    return nil
  end
end