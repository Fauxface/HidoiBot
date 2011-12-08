# Ng Guoyou
# ThreadStatus.rb
# Interface to display running threads.

class ThreadStatus < BotPlugin
  def initialize
    # Authorisations
    @requiredAuth = 0

    # Required plugin stuff
    name = self.class.name
    hook = 'threads'
    processEvery = false
    help = "Function: Returns running threads."
    super(name, hook, processEvery, help)
  end

  def main(m)
    m.reply(threadInfo) if m.authR(@requiredAuth)
    return nil
  rescue => e
    handleError(e)
    return nil
  end

  def threadInfo
    return Thread.list.join("\n")
  end
end