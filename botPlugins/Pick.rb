# Ng Guoyou
# Pick.rb
# Picks n objects from a list.

class Pick < BotPlugin
  def initialize
    # Authorisations
    @reqPickAuth = 0

    # Triggers
    @shuffleTrigger = 'shuffle'
    @pickTrigger = 'pick'

    # Required plugin stuff
    name = self.class.name
    @hook = [@pickTrigger, @shuffleTrigger]
    processEvery = false
    help = "Usage: #{@hook} (1-9) <items, seprated by commas>\nFunction: Picks n items from a list."
    super(name, @hook, processEvery, help)
  end

  def main(m)
    if m.authR(@reqPickAuth)
      list = m.stripTrigger

      case m.trigger
      when @shuffleTrigger
        rs = parseOptions(list).shuffle.join(", ")
      when @pickTrigger
        picks = m.args[0].to_i
        !(/[0-9]/ === picks.to_s) ? picks = 1 : list.gsub!("#{picks.to_s} ", '') # No pick count given, reinsert picks which was actually a pick option
        rs = parseOptions(list).sample(picks).join(", ")
      end

      m.reply(rs)
    end

    return nil
  rescue => e
    handleError(e)
    return nil
  end

  def parseOptions(s)
    s.gsub!(', ', ',')
    return s.split(/[,]/)
  end
end