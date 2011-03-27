# encoding:utf-8
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
        @events.each{ |event|
            begin
                if event["time"] < Time.now
                    handleEvent(event) if event != nil
                end
            rescue
                # If malformed event, delete it
                event["occurrence"] = 'inactive'
            end
        }
        return nil
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
        @events.delete_if{ |event|
            event["type"] == eventType
        }
    end
    
    def deleteEventOccurrence(eventOccurrence)
        @events.delete_if{ |event|
            event["occurrence"] == eventOccurrence
        }
    end
    
    def cleanupEvents
        @events.delete_if{ |event|
            event["occurrence"] == 'inactive'
        }
        @events.compact!
    end
    
    def addEvent(user, type, time, occurrence, occurrenceOffset, *message)
        if time.class != Time
            time = Time.at(time.to_i)
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
        
        if message[0] != nil
            event["message"] = message[0]
        else
            event["message"] = nil
        end
        
        @events[@events.size] = event
    end
end