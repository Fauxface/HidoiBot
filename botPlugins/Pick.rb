# Ng Guoyou
# Pick.rb
# Picks n objects from a list.

class Pick < BotPlugin
  def initialize
    # Authorisations
    @reqPickAuth = 0

    # Required plugin stuff
    name = self.class.name
    @hook = ['pick', 'pickone']
    processEvery = false
    help = "Usage: #{@hook} (1-9) <items, seprated by commas>\nFunction: Picks n items from a list."
    super(name, @hook, processEvery, help)
  end

  def main(m)
    if m.authR(@reqPickAuth)
      list = m.stripTrigger
      picks = m.args[0].to_i
      !(/[1-9]/ === picks.to_s) ? picks = 1 : list.gsub!("#{picks.to_s} ", '') # No pick count given, reinsert picks which was actually an option
      parsedList = parseOptions(list)
      m.reply(pick(picks, parsedList))
    end

    return nil
  rescue => e
    handleError(e)
    return nil
  end

  def pick(picks, list)
    pickItem = Array.new

    picks.times do
      if !list.empty?
        pickNumber = rand(list.size)
        pickItem.push(list[pickNumber])
        list.delete_at(pickNumber)
      end
    end

    return pickItem.join(', ')
  end

  def parseOptions(s)
    s.gsub!(', ', ',')
    return s.split(/[,]/)
  end
end