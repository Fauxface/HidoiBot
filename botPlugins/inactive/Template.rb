class Template < BotPlugin
  def initialize
    # Authorisations
    @reqQuackAuth = 0

    # Strings
    @noQuackMsg = "No quack."

    # Required plugin stuff
    name = self.class.name
    @hook = nil
    processEvery = false
    help = "Usage: #{@hook} <term>\nFunction: fgsfds."
    super(name, @hook, processEvery, help)
  end

  def main(m)
    case m.mode
    when 'quack'
      m.reply("Quack.") if m.authR(@reqQuackAuth)
    else
      m.reply(@noQuackMsg)
    end

    return nil
  rescue => e
    handleError(e)
    return nil
  end
end