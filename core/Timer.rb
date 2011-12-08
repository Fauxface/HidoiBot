# encoding:utf-8
# Ng Guoyou
# Timer.rb
# Does the checking for events (eg. pingchecks, reminders)

class Event
  attr_accessor :message
  attr_accessor :occurrence
  attr_accessor :occurrenceOffset
  attr_accessor :time
  attr_accessor :type
  attr_accessor :user
end

module Timer
  def timerInitialize
    @events = Array.new
  end

  def timer
    puts "Timer is running...\n"
    loop do
      sleep 1
      checkEvents
      cleanupEvents
    end
  rescue => e
    handleError(e)
  end

  def checkEvents
    @events.each { |event|
      begin
        if event.time < Time.now
          handleEvent(event) if event != nil
        end
      rescue
        # If malformed event, delete it
        event.occurrence = 'inactive'
      end
    }
  end

  def handleEvent(event)
    if event.class == Event && event.occurrence != 'inactive'
      case event.type
      when 'pingServer'
        send "PING #{Time.now.to_f}"
      when 'reminder'
        sayTo(event.user, event.message)
      when 'pingTimeout'
        puts 'PING TIMEOUT'
        reconnect
      when 'pingCheck'
        pingServer
      end

      handleOccurrence(event)
    end
  end

  def handleOccurrence(event)
    case event.occurrence
    when 'single'
      event.occurrence = 'inactive'
    when 'recurring'
      event.time = event.time + event.occurrenceOffset.to_i
    end
  end

  def deleteEventType(eventType)
    @events.delete_if { |event|
      event.type == eventType
    }
  end

  def deleteEventOccurrence(eventOccurrence)
    @events.delete_if { |event|
      event.occurrence == eventOccurrence
    }
  end

  def deleteReminderUser(user)
    @events.delete_if { |event|
      event.user == user
      event.type == 'reminder'
    }
  end

  def cleanupEvents
    @events.delete_if { |event|
      event.occurrence == 'inactive'
    }
    @events.compact!
  end

  def addEvent(user, type, time, occurrence, occurrenceOffset, *message)
    time = Time.at(time.to_i) if !time.is_a?(Time)

    # Input checking
    if occurrence != 'single' && occurrence != 'recurring'
      raise "Timer: Unsupported reminder type #{occurrence}"
    end

    if !time.is_a?(Time)
      raise "Timer: Bad time object - #{time} #{time.class}"
    end

    event = Event.new
    event.user = user
    event.type = type
    event.time = time
    event.occurrence = occurrence
    event.occurrenceOffset = occurrenceOffset

    message[0] != nil ? event.message = message[0] : event.message = nil
    @events[@events.size] = event
  rescue => e
    handleError(e)
  end
end