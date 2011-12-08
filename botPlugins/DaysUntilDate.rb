# Ported from HidoiBot1
# Ng Guoyou
# DaysUntilDate.rb
# Calculates the number of days to a given date DDMMYY

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

  def main(m)
    date = m.args[0]
    m.reply(prettify(calcDaysUntilDate(parseDate(date))))
    return nil
  rescue => e
    handleError(e)
    return sayf("Invalid date format. Enter any parsable date (eg. DDMMYY).")
  end

  def parseDate(dateIn)
    date = dateIn.slice(/[\d]+/)

    if date.length != 6
      return DateTime.parse(dateIn).to_date
    elsif date.length == 6
      day = date[0..1]
      month = date[2..3]
      year = "20#{date[4..5]}"
      combinedDate = "#{day}/#{month}/#{year}"

      return Date.parse(combinedDate)
    end
  rescue => e
    handleError(e)
    raise "Invalid date format"
  end

  def calcDaysUntilDate(deadline)
    weekdays = 0
    daysToDate = (deadline - Date.today).to_i

    Date.today.step(deadline - 1) { |day|
      weekdays += 1 if (!day.saturday? && !day.sunday?)
    }

    return { days: daysToDate,
             weekdays: weekdays,
             deadline: deadline }
  rescue => e
    handleError(e)
    return nil
  end

  def prettify(dates)
    daysPlural = dates[:days].abs != 1 ? 's' : ''
    weekdaysPlural = dates[:weekdays] != 1 ? 's' : ''

    if dates[:days] < 0
      return "The date given is #{dates[:days].abs} day#{daysPlural} in the past."
    elsif dates[:days] == 0
      return "That would be today."
    elsif dates[:weekdays] == 0
      return "#{dates[:days]} day#{daysPlural} until #{dates[:deadline]}"
    elsif dates[:days] == dates[:weekdays]
      return "#{dates[:weekdays]} weekday#{weekdaysPlural} until #{dates[:deadline]}"
    else
      return "#{dates[:days]} day#{daysPlural} (#{dates[:weekdays]} weekday#{weekdaysPlural}) until #{dates[:deadline]}"
    end
  rescue => e
    handleError(e)
    return nil
  end
end