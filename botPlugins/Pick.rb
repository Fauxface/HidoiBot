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
    @pickOneTrigger = 'pickone'

    # Required plugin stuff
    name = self.class.name
    @hook = [@pickTrigger, @shuffleTrigger, @pickOneTrigger]
    processEvery = false
    help = "Usage: #{@hook} (number of picks) <items, seprated by commas>\nFunction: Picks n items from a list."
    super(name, @hook, processEvery, help)
  end

  def main(m)
    if m.authR(@reqPickAuth)
      list = parseOptions(m.stripTrigger)

      case m.trigger
      when @shuffleTrigger
        rs = list.shuffle.join(", ")
      when @pickTrigger
        picks = m.args[0]
        (/[0-9]/ === picks.to_s) ? list[0] = list[0].to_s.gsub("#{picks.to_s} ", '') : picks = 1  # If no pick count was given assume picks = 1
        rs = list.sample(picks.to_i).join(", ")
      when @pickOneTrigger
        picks = 1
        rs = list.sample(picks.to_i).join(", ")
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