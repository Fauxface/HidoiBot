class Reminder < BotPlugin
    def initialize
        # Authorisations
        @requiredLevelForOthers = 3
        @requiredLevelForClear = 3
        
        # Strings
        @noAuthMessage = 'You are not authorised for this.'
        
        # Required plugin stuff
        name = self.class.name
        @hook = 'remind'
        processEvery = false
        help = "Usage: #{@hook} (clearall|clearrecurring|<userOrChannelToRemind|me> about <event> (in|every) <time>)\nFunction: Sets or clears reminders."
        super(name, @hook, processEvery, help)
    end

    def main(data)
        @givenLevel = data["authLevel"]
        
        mode = arguments(data)[0]
        case mode
            when 'clearall'
                if checkAuth(@requiredlevelForClear)
                    return clearReminders
                else
                    return sayf(@noAuthMessage)
                end
            when 'clearrecurring'
                if checkAuth(@requiredLevelForClear)
                    return clearRecurring
                else
                    return sayf(@noAuthMessage)
                end
            else
                return addReminder(data)
        end
    rescue => e
        handleError(e)
        return nil
    end
    
    def addReminder(data)
        extract = data["message"].split(/(remind | about | in | every )/)
        type = 'reminder'
        user = extract[2]
        message = extract[4]
        timeRelative = extract[6]
        parsedTime = Time.at(parseRemindTime(timeRelative))
        isRecurring = data["message"].split(/(#{user}|about| #{message} | #{timeRelative})/)[6]
        
        # Checking for type
        if isRecurring == 'every'
            occurrence = 'recurring'
            occurrenceOffset = parseRemindTime(timeRelative)
            parsedTime += Time.now.to_i
        elsif isRecurring == 'in'
            occurrence = 'single'
            occurrenceOffset = 0
            parsedTime += Time.now.to_i
        elsif isRecurring == 'at'
            # Not implemented yet
        end
        
        # Checking for authorisation
        if user == 'me' || user == data['sender'] && occurrence != 'recurring'
            # No auth required for single event for self
            user = data['sender']            
            rs = sayf('Reminder added.')
            return "addEvent('#{user}', '#{type}', '#{parsedTime.to_i}', '#{occurrence}', '#{occurrenceOffset}', '#{message}'); #{rs}"
            
        elsif checkAuth(@requiredLevelForOthers)
            # Auth required for single/recurring event for other people            
            rs = sayf('Reminder added.')
            return "addEvent('#{user}', '#{type}', '#{parsedTime.to_i}', '#{occurrence}', '#{occurrenceOffset}', '#{message}'); #{rs}"
            
        elsif !checkAuth(@requiredLevelForOthers)
            return sayf(@noAuthMessage)
        end
    rescue => e
        rs = sayf("Error in addReminder: Check syntax.")
        handleError(e)
        return rs
    end
    
    def clearRecurring
        rs = sayf('Clearing recurring events.')
        return "deleteEventOccurrence('recurring'); #{rs}"
    end
    
    def clearReminders
        rs = sayf('Clearing all reminders.')
        return "deleteEventType('reminder'); #{rs}"
    end
    
    def parseRemindTime(time)
		timeUnit = time[/[a-z]+$/i]
		timeDigit = time[/[0-9\.]+/]

		if timeUnit == /(s|seconds?|secs?)/
		elsif timeUnit == /(m|minutes?|mins?)/
			timeDigit = timeDigit.to_f * 60
		elsif timeUnit == /(h|hrs?|hours?)/
			timeDigit = timeDigit.to_f * 60 * 60
		elsif timeUnit == /(d|days?)/
			timeDigit = timeDigit.to_f * 24 * 60 * 60
		end
		
		remindTime = timeDigit.to_i
        return remindTime
    end
    
end