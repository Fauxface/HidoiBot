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
            if event["time"] < Time.now
                handleEvent(event) if event != nil
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
                sendTo(event["user"], event["message"])
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
    
    def cleanupEvents
        @events.delete_if{ |event|
            event["occurrence"] == 'inactive'
        }
        @events.compact!
    end
    
    def addEvent(user, type, time, occurrence, occurrenceOffset, *message)
        event = {
            "user" => user,
            "type" => type,
            "time" => time,
            "occurrence" => occurrence,
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