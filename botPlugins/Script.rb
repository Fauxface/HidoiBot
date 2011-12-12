# Ng Guoyou
# Script.rb
# Interface for eval()
# Dangerous!

class Script < BotPlugin
  def initialize
    # Authorisations
    @reqScriptLevel = 3

    # Required plugin stuff
    name = self.class.name
    @hook = 'script'
    processEvery = false
    help = "Usage: #{@hook} <term>\nFunction: Evaluates term."
    super(name, @hook, processEvery, help)
  end

  def main(m)
    m.reply eval(m.stripTrigger) if m.authR(@reqScriptLevel)
    return nil
  rescue => e
    handleError(e)
    m.reply(e)
    return nil
  end
end