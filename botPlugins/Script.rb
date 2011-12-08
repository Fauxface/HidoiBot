# Ng Guoyou
# Script.rb
# Interface for eval()
# Dangerous!

class Script < BotPlugin
  def initialize
    # Authorisations
    @reqScriptLevel = 3

    # Strings
    @noAuthMessage = 'You are not authorised for this.'

    # Required plugin stuff
    name = self.class.name
    @hook = 'script'
    processEvery = false
    help = "Usage: #{@hook} <term>\nFunction: Evaluates term."
    super(name, @hook, processEvery, help)
  end

  def main(m)
    return eval(m.stripTrigger) if m.auth(@reqScriptLevel)
  rescue => e
    handleError(e)
    return sayf(e)
  end
end