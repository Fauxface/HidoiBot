# encoding:utf-8
# Ng Guoyou
# Timer.rb
# Does the checking for events (eg. pingchecks, reminders)

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
        if event["time"] < Time.now
          handleEvent(event) if event != nil
        end
      rescue
        # If malformed event, delete it
        event["occurrence"] = 'inactive'
      end
    }
  end

  def handleEvent(event)
    if event != nil && event["occurrence"] != 'inactive'
      case event["type"]
      when 'pingServer'
        send "PING #{Time.now.to_f}"
      when 'reminder'
        sayTo(event["user"], event["message"])
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
    case event["occurrence"]
    when 'single'
      event["occurrence"] = 'inactive'
    when 'recurring'
      addEvent(event["user"], event["type"], event["time"] + event["occurrenceOffset"].to_i, event["occurrence"], event["occurrenceOffset"], event["message"])
      event["occurrence"] = 'inactive'
    end
  end

  def deleteEventType(eventType)
    @events.delete_if { |event|
      event["type"] == eventType
    }
  end

  def deleteEventOccurrence(eventOccurrence)
    @events.delete_if { |event|
      event["occurrence"] == eventOccurrence
    }
  end

  def deleteReminderUser(user)
    @events.delete_if { |event|
      event["user"] == user
      event["type"] == 'reminder'
    }
  end

  def cleanupEvents
    @events.delete_if { |event|
      event["occurrence"] == 'inactive'
    }
    @events.compact!
  end

  def addEvent(user, type, time, occurrence, occurrenceOffset, *message)
    if !time.is_a?(Time)
        time = Time.at(time.to_i)
    end

    # Input checking
    if occurrence != 'single' && occurrence != 'recurring'
      raise "Timer: Unsupported reminder type #{occurrence}"
    end

    if !time.is_a?(Time)
      raise "Timer: Bad time object - #{time} #{time.class}"
    end

    event = {
      # Who to remind
      "user" => user,

      # Type of event, see handleEvent
      "type" => type,

      # Time in integer
      "time" => time,

      # Type of event (single, recurring)
      "occurrence" => occurrence,

      # Time between recurring events
      "occurrenceOffset" => occurrenceOffset
    }

    message[0] != nil ? event["message"] = message[0] : event["message"] = nil
    @events[@events.size] = event
  rescue => e
    handleError(e)
  end
end
