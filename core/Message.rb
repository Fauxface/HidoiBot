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
    # Basically calls IRC's say.
    #
    # Params:
    # +message+:: What to send to the person. Will be converted to a string.

    @origin.say(message)
  end

  def sayTo(channel, message)
    # Basically calls IRC's sayTo.
    #
    # Params:
    # +channel+:: Channel or person to send the PRIVMSG.
    # +message+:: What to send to the person. Will be converted to a string.

    @origin.sayTo(channel, message)
  end

  def auth(givenAuth)
    # Returns true if this +Message+ has a sufficient authLevel and false if it does not.
    return @authLevel >= givenAuth
  end

  def noAuth
    # Built-in method for no auth message. Replies to sender telling him he does not have a sufficient authLevel.
    @origin.say(@noAuthMsg)
  end

  def authR(givenAuth)
    # Auth and noAuth combined together.
    # Returns true if this +Message+ has authLevel >= givenAuth and false otherwise.
    # Also if the sender has an insufficiently high authLevel this tells him so.
    #
    # Params:
    # ::givenAuth+:: Required auth level.

    a = auth(givenAuth)
    noAuth if !a
    return a
  end

  def args
    # Returns args in an array, trigger removed
    # For something like "~chat about the pig", the returned value will be ["about", "the", "pig"].
    args = @message.split(' ')

    if args.class == Array
      args.delete_at(0) # Delete trigger
      return args
    else
      return nil
    end
  end

  def mode
    # Returns first argument.
    # For something like "~chat about the pig", the returned value will be "about".
    return args[0]
  end

  def stripTrigger
    # Returns args, joined together
    # For something like "~chat about the pig", the returned value will be "about the pig".
    msg = args
    return msg.class == Array ? msg.join(' ') : nil
  end

  def shiftWords(n)
    # Removes n words from the start of @message
    #
    # Params:
    # +n+:: Number of words to remove.

    return @message.split(' ')[n..-1].join(' ')
  end

  def truncateWords(n)
    # Removes n words from the end of @message
    #
    # Params:
    # +n+:: Number of words to remove.

    return @message.split(' ')[0..-n].join(' ')
  end
end