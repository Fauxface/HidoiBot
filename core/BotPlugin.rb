# encoding:utf-8
class BotPlugin
    begin
        require 'json'
    rescue LoadError
        begin
            require 'json_pure'
        rescue LoadError
            puts '"json" and "json_pure" gems not found. Some plugins might not work correctly.'
        end
    end
    
    # For getOriginObject
    include ObjectSpace
    
    def initialize(botModuleName, hook, processEvery, *help)
        # Make a doBotsMapping method
        if hook.class == Array and hook.size > 1
            # If multiple hooks
            hook.each { |i|
                $bot1.doPluginMapping(i, botModuleName, processEvery)
                $bot1.doPluginHelp(i, help[0]) if help[0] != nil
            }
        else
            # If single hook
            $bot1.doPluginMapping(hook, botModuleName, processEvery)
            $bot1.doPluginHelp(hook, help[0]) if help[0] != nil
        end
        
        puts "Bot plugin #{botModuleName} loaded."
    end
    
    def getOriginObject(data)
        # Returns origin of data via an object.object_id contained in data["originId"]
        # So that you can access methods from the origin
        return ObjectSpace._id2ref(data["originId"])
    rescue => e
        handleError(e)
        return nil
    end
    
    def authCheck(requiredLevel)
        # Returns true is you have authorisation, else return false
        if @givenLevel == nil
            raise "Error in BotPlugin: authRequired: @givenLevel is not defined in plugin"
        end
        
        if requiredLevel <= @givenLevel
            return true
        elsif requiredLevel > @givenLevel
            return false
        end
    rescue => e
        return false
    end
    
    def checkAuth(requiredLevel)
        # Alias, I always confuse the ordre
        return authCheck(requiredLevel)
    end
    
    def arguments(data)
        # Delete trigger but split message, arguments(data)[someInteger] can be used for mode selection
        arguments = data["message"].split(' ')
        if arguments.class == Array
            # Delete trigger from arguments
            arguments.delete_at(0)
            return arguments
        else
            return nil
        end
    end
    
    def detectTrigger(data)
        return data["message"].split(' ')[0]
    end
    
    def stripTrigger(data)
        # Delete trigger but leave remaining message intact
        return arguments(data).join(' ')
    end
    
    def stripWordsFromStart(s, number)
        splitWords = s.split(' ')
        
        for i in 1..number
            splitWords.delete_at(0)
        end
        
        return splitWords.join(' ')
    end
    
    def stripWordsFromEnd(s, number)
        splitWords = s.split(' ')
        splitWords = splitWords.reverse
                
        for i in 1..number
            splitWords.delete_at(0)
        end
        
        return splitWords.reverse.join(' ')
    end
    
    def detectMode(data)
        # Returns first block of message
        # This can be used to detect if a plugin processing every line was called using a trigger
        arguments = data["message"].split(' ')
        return arguments[1]
    end
    
    def escapeSyntax(s)
        # Use this if you are getting syntax errors in IRC from breaking eval
        # Use escapeSyntaxHard IF YOU GOT MAD LIKE I DID AT THE ATROCIOUS ESCAPING REQUIRED
        s = s.gsub(/[\\]/, '\\\\\\') if s.class == String
        s = s.gsub(/[']/, '\\\\\'') if s.class == String
        s = s.gsub(/["]/, '\\\\\"') if s.class == String
        return s
    end
    
    def escapeSyntaxHard(s) 
        # Apostrophes more like hate
        # http://weblog.jamisbuck.org/2004/12/19/sqlite3-bindings-for-ruby
        # Prepared statements
        s = s.gsub(/['"]/, '`')
        return s
    end
    
    def sayf(s)
        # Formats a string in prepration for returns to the main bot
        rs = "say '#{escapeSyntax(s)}'"
        return rs
    end
    
    def bold(s)
        boldChar = "\002"
        s.insert(0, boldChar)
        s.insert(s.size, boldChar)
        
        return s
    end
    
    def italic(s)
        # Or oblique, whichever floats your boat
        italicChar = "\011"
        s.insert(0, italicChar)
        s.insert(s.size, italicChar)
        
        return s
    end
    
    def colour(s, textColour, highlightColour=nil)
        colourChar = "\003"
        
        if !isColour?(textColour)
            raise "textColour is not a vaild colour code (0-15) textColour: #{textColour}"
        elsif !isColour?(highlightColour) && highlightColour != nil
            raise "highlightColour is not a vaild colour code (0-15) highlightColour: #{textColour}"
        end
        
        if highlightColour != nil
            colourCodes = "#{textColour},#{highlightColour}"
        elsif highlightColour == nil
            colourCodes = "#{textColour}"
        end
        
        s.insert(0, colourCodes)
        s.insert(0, colourChar)
        s.insert(s.size, colourChar)
        
        return s
    rescue => e
        handleError(e)
        return s
    end
    
    def isColour?(colourCode)
        if /^(0?[0-9]|[0-1][0-5]?)$/ === "#{colourCode}" # Checks for range 0-15
            return true
        else
            return false
        end
    end
    
    def underline(s)
        underlineChar = "\037"
        s.insert(0, underlineChar)
        s.insert(s.size, underlineChar)
        
        return s
    end
    
    def reverseColour(s)
        reverseChar = "\026"
        s.insert(0, reverseChar)
        s.insert(s.size, reverseChar)
        
        return s
    end
    
    def clearCodes()
        normalChar = "\017"
        return normalChar
    end
    
    def decimalPlace(f)
        # To two decimal places
        return ((f * 100).round)/100.0
    end
    
    def humaniseSeconds(second)
        # Converts seconds in integer to this format, with proper grammar:
        # x years, y months, z, weeks, a days, b hours, c minutes, d seconds
        secondsInMinute = 60
        secondsInHour = 60 * 60
        secondsInDay = 60 * 60 * 24
        secondsInWeek = 60 * 60 * 24 * 7
        secondsInMonth = 60 * 60 * 24 * 30 # 1 month is taken to be 30 days
        secondsInYear = 60 * 60 * 24 * 365
        
        unitSecond = "seconds"
        unitMinute = "minutes"
        unitHour = "hours"
        unitDay = "days"
        unitWeek = "weeks"
        unitMonth = "months"
        unitYear = "years"
        
        second = second.abs
        minute = second / secondsInMinute
        hour = second / secondsInHour
        day = second / secondsInDay
        week = second / secondsInWeek
        month = second / secondsInMonth
        year = second / secondsInYear
        
        trailingSecond = second % secondsInMinute
        trailingMinute = (second % secondsInHour) / secondsInMinute
        trailingHour = (second % secondsInDay) / secondsInHour
        trailingDay = (second % secondsInWeek) / secondsInDay
        trailingWeek = (second % secondsInMonth) / secondsInWeek
        trailingMonth = (second % secondsInYear) / secondsInMonth
        
        # Check for singluar
        unitSecond = "second" if trailingSecond == 1 || second == 1
        unitMinute = "minute" if trailingMinute == 1
        unitHour = "hour" if trailingHour == 1
        unitDay = "day" if trailingDay == 1
        unitWeek = "week" if trailingWeek == 1
        unitMonth = "month" if trailingMonth == 1
        unitYear = "year" if year == 1

        humanDate = Array.new
        humanDate.push("#{year} #{unitYear}") if year > 0
        humanDate.push("#{trailingMonth} #{unitMonth}") if month >= 1 && trailingMonth > 0
        humanDate.push("#{trailingWeek} #{unitWeek}") if week >= 1 && trailingWeek > 0
        humanDate.push("#{trailingDay} #{unitDay}") if day >= 1 && trailingDay > 0
  
        humanDate.push("#{trailingHour} #{unitHour}") if hour >= 1 && trailingHour > 0
        humanDate.push("#{trailingMinute} #{unitMinute}") if minute >= 1 && trailingMinute > 0
        
        if second >= 1 && trailingSecond > 0
            humanDate.push("#{trailingSecond} #{unitSecond}")
        elsif second == 0
            humanDate.push("#{second} #{unitSecond}")
        end

        return humanDate.join(", ")      
    end
    
    def loadSettings
        @configPath = 'botPlugins/settings/'
        @s = JSON.parse(open("#{@configPath}/#{@settingsFile}", "a+").read)
    rescue => e
        handleError(e)
    end
    
    def saveSettings
        @configPath = 'botPlugins/settings/'
        f = File.open("#{@configPath}/#{@settingsFile}", "w")
        f.puts @s.to_json
        f.close
    rescue => e
        handleError(e)
    end
    
    def handleError(e)
        puts e
        puts e.backtrace.join("\n")
    end
end