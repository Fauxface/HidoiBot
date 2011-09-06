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

  def main(data)
    if data["trigger"] == @hook[0]
      mode = 'auth'
      password = arguments(data)[0]
    elsif data["trigger"] == @hook[1]
      mode = 'deauth'
    elsif data["trigger"] == @hook[2]
      mode = 'checkauth'
    end

    case mode
    when 'auth'
      return "auth(data)"
    when 'deauth'
      return "deauth('#{data["hostname"]}')"
    when 'checkauth'
      return sayf("You have authorisation level: #{data["authLevel"]}")
    else
      return nil
    end
  rescue => e
    handleError(e)
    return nil
  end
end