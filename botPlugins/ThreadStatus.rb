# Ng Guoyou
# ThreadStatus.rb
# Interface to display running threads.

class ThreadStatus < BotPlugin
  def initialize
    # Authorisations
    @requiredAuth = 0

    # Strings
    @noAuthMsg = "You are not authorised for this."

    # Required plugin stuff
    name = self.class.name
    hook = 'threads'
    processEvery = false
    help = "Function: Returns running threads."
    super(name, hook, processEvery, help)
  end

  def main(data)
    @givenLevel = data["authLevel"]

    return authCheck(@requiredAuth) ? sayf(threadInfo) : sayf(@noAuthMsg)
  rescue => e
    handleError(e)
    return nil
  end

  def threadInfo
    return Thread.list.join("\n")
  end
end