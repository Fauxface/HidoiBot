# encoding:utf-8
# Ng Guoyou
# Timer.rb
# Does the checking for events (eg. pingchecks, reminders)

class Timer
  class Event
    attr_accessor :message
    attr_accessor :occurrence
    attr_accessor :occurrenceOffset
    attr_accessor :time
    attr_accessor :type
    attr_accessor :user
    attr_accessor :origin
  end

  def initialize
    timer # Starts the timer
  end

  def timer
    # Main timer loop, runs checking and cleanup methods

    @events = Array.new # Events list

    Thread.new do
      loop do
        sleep 1
        checkEvents
        cleanupEvents
      end
    end
  rescue => e
    handleError(e)
  end

  def checkEvents
    # Checks if each event in the event list is due and passes it to handleEvent if it is

    @events.each { |event|
      begin
        if event.time < Time.now
          handleEvent(event) if event != nil
        end
      rescue
        # If malformed event, flag it for deletion
        event.occurrence = 'inactive'
      end
    }
  end

  def handleEvent(event)
    # Handles logic for event types. Pings, ping timeouts and reminders.
    #
    # Params:
    # +event+:: An +Event+ to be handled.

    if event.class == Event && event.occurrence != 'inactive'
      case event.type
      when 'pingServer'
        event.origin.send "PING #{Time.now.to_f}"
      when 'reminder'
        event.origin.sayTo(event.user, event.message)
      when 'pingTimeout'
        puts 'PING TIMEOUT'
        event.origin.reconnect
      when 'pingCheck'
        event.origin.pingServer
      end

      handleOccurrence(event)
    end
  end

  def handleOccurrence(event)
    # Handles logic for event recurrence. Inactivates obsolete events which flags them for removal.
    #
    # Params:
    # +event+:: An +Event+ to be handled.

    case event.occurrence
    when 'single'
      event.occurrence = 'inactive'
    when 'recurring'
      event.time = event.time + event.occurrenceOffset.to_i
    end
  end

  def deleteEventType(eventType)
    # Deletes all events of type +eventType+ in the events list.
    #
    # Params:
    # +eventType+:: Type of event to be purged from the event list.

    @events.delete_if { |event|
      event.type == eventType
    }
  end

  def deleteEventOccurrence(eventOccurrence)
    # Deletes all events of occurrence +eventOccurrence+ in the events list.
    #
    # Params:
    # +eventOccurrence+:: Occurrence of event to be purged from the event list.

    @events.delete_if { |event|
      event.occurrence == eventOccurrence
    }
  end

  def deleteReminderUser(user)
    # Deletes all events from +user+ in the events list.
    #
    # Params:
    # +user+:: User (sender) of event to be purged from the event list.

    @events.delete_if { |event|
      event.user == user
      event.type == 'reminder'
    }
  end

  def cleanupEvents
    # Deletes all inactive events in the events list.

    @events.delete_if { |event|
      event.occurrence == 'inactive'
    }
    @events.compact!
  end

  def addEvent(user, type, time, occurrence, occurrenceOffset, origin, *message)
    # Adds an event to the event list.
    #
    # Params:
    # +user+:: User (sender) of event.
    # +type+:: Type of event: ping, pingTimeout, pingCheck or reminder.
    # +time+:: Time the event is due.
    # +occurrence+:: Occurrence: 'single' or 'recurring'.
    # +occurrenceOffset+:: Interval of recurring events. Should be set to 0 for single events.
    # +origin+:: Origin of event.
    # +message+:: Optional. Used for reminder text.

    time = Time.at(time.to_i) if !time.is_a?(Time) # Parses integer time as Time objects

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
    event.origin = origin
    event.message = (message[0] != nil ? message[0] :  nil)
    @events[@events.size] = event
  rescue => e
    handleError(e)
  end

  def handleError(e)
    # Handles errors by printing it and its backtrace.
    #
    # Params:
    # +e+:: Error to handle.

    puts e
    puts e.backtrace
  end
end