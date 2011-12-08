class Message
  attr_accessor :sender
  attr_accessor :realname
  attr_accessor :hostname
  attr_accessor :messageType
  attr_accessor :channel
  attr_accessor :message
  attr_accessor :rawMessage
  attr_accessor :authLevel
  attr_accessor :time
  attr_accessor :serverGroup
  attr_accessor :originId
  attr_accessor :origin
  attr_accessor :processEvery
  attr_accessor :trigger

  def initialize
    @time = Time.now
    @noAuthMsg = "You are not authorised for this." # Default no auth message
  end
  
  def reply(message)
    @origin.say(message)
  end
  
  def sayTo(channel, message)
    @origin.sayTo(channel, message)
  end
  
  def auth(givenAuth)
    # Returns true if authorised and false if not
    return @authLevel >= givenAuth
  end

  def noAuth
    # Built-in method for no auth message
    @origin.say(@noAuthMsg)
  end
  
  def authR(givenAuth)
    # Auth and noAuth combined together
    a = auth(givenAuth)
    noAuth if !a
    return a
  end

  #def trigger
    # Returns trigger
    #return @message.split(' ').shift(1)
  #end
  
  def args
    # Returns args in an array, trigger removed
    args = @message.split(' ')
    
    if args.class == Array
      args.delete_at(0) # Delete trigger
      return args
    else
      return nil
    end
  end
  
  def mode
    # Returns first argument
    return args[0]
  end
  
  def stripTrigger
    # Returns args, joined together
    msg = args
    return msg.class == Array ? msg.join(' ') : nil
  end
  
  def shiftWords(n)
    return @message.split(' ')[n..-1].join(' ')
  end
  
  def truncateWords(n)
    return @message.split(' ')[0..-n].join(' ')
  end
end 