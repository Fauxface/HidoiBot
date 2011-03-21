# Ported from HidoiBot1
class DaysUntilDate < BotPlugin
    require 'date'
    
    def initialize
        # Required plugin stuff
        name = self.class.name
        hook = 'until'
        processEvery = false
        help = "Usage: #{hook} <DDMMYY>\nFunction: Calculates days left until given date."
        super(name, hook, processEvery, help)
    end

    def main(data)
        date = arguments(data)[0]
        return sayf(calcDaysUntilDate(parseDate(date)))
    rescue => e
        handleError(e)
        return nil
    end
    
    def parseDate(date)
        date = date.slice(/[\d]+/)
        if date.length != 6
            return nil
        elsif date.length == 6
            day = date[0..1]
            month = date[2..3]
            year = "20#{date[4..5]}"
            combinedDate = "#{day}/#{month}/#{year}"
            puts Date.parse(combinedDate).inspect
            return Date.parse(combinedDate)
        end
    end
    
    def calcDaysUntilDate(deadline)
        daysToDate = 0
        weekdays = 0
    
        for days in Date.today.upto deadline
            daysToDate = daysToDate + 1
        end
        
        (Date.today..deadline).select{ |day|
            weekdays = weekdays + 1 if day.wday > 0 && day.wday < 6
        }
    
        if daysToDate < 1
            return "The date given is in the past."
        elsif daysToDate > 0
            return "#{daysToDate.to_i.to_s} days, #{weekdays} weekdays until #{deadline}"
        end
    rescue => e
        handleError(e)
        return nil
    end
end