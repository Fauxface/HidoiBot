# Ng Guoyou
# Reminder.rb
# Handles alarm and reminders. These are non-persistent.

require 'time'

class Reminder < BotPlugin
  def initialize
    # Authorisations
    @requiredLevelForOthers = 3
    @requiredLevelForClear = 3
    @requiredReminderLevel = 0

    # Strings
    @errorMessage = "Error in addReminder: Check console for details."
    @reminderAddedMessage = "Reminder added."
    @clearAllMessage = "Clearing all reminders."
    @clearPersonalMessage = "Clearing your reminders."
    @clearRecurringMessage = "Clearing recurring events."

    # Required plugin stuff
    name = self.class.name
    @hook = ['remind', 'reminder']
    processEvery = false
    help = "Usage: #{@hook} (clearall|clearrecurring|clearmine|<userOrChannelToRemind|me> about <event> (in|every|at) <time>)\nFunction: Sets or clears reminders. Takes in a relative time for 'in' and 'every' and an absolute time for 'at'. (eg. at 2011-11-11 05:00 or November 5th, 2011, 7:48 pm. Uses Ruby's Time.parse for absolute date-times."
    super(name, @hook, processEvery, help)
  end

  def main(m)
    case m.mode
    when 'clearall'
      clearReminders(m) if m.authR(@requiredLevelForClear)
    when 'clearrecurring'
      clearRecurring(m) if m.authR(@requiredLevelForClear)
    when 'clearmine'
      clearMyReminders(m) if m.authR(@requiredReminderLevel)
    else
      addReminder(m) if m.authR(@requiredReminderLevel)
    end

    return nil
  rescue => e
    handleError(e)
    return nil
  end

  def addReminder(m)
    extract = m.message.split(/(remind | about | in | every | at )/)
    type = 'reminder'
    user = extract[2]
    message = extract[4]
    givenTime = extract[6]

    isRecurring = m.message.split(/(#{user}|about| #{message} | #{givenTime})/)[6]

    # Making time given relative
    if isRecurring == 'every' || isRecurring == 'in'
      parsedTime = Time.now.to_i + Time.at(parseRemindTime(givenTime)).to_i
    elsif isRecurring == 'at'
      parsedTime = Time.parse(givenTime)
    end

    # Checking for type
    if isRecurring == 'every'
      occurrence = 'recurring'
      occurrenceOffset = givenTime.to_i
    elsif isRecurring == 'in'
      occurrence = 'single'
      occurrenceOffset = 0
    elsif isRecurring == 'at'
      occurrence = 'single'
      occurrenceOffset = 0
    end

    # Checking for authorisation
    if user == 'me' || user == m.sender && occurrence != 'recurring'
      # No auth required for single event for self
      m.origin.timer.addEvent(m.sender, type, parsedTime.to_i, occurrence, occurrenceOffset, m.origin, message)
      m.reply(@reminderAddedMessage)

    elsif m.authR(@requiredLevelForOthers)
      # Auth required for single/recurring event for other people
      m.origin.timer.addEvent(user, type, parsedTime.to_i, occurrence, occurrenceOffset, m.origin, message)
      m.reply(@reminderAddedMessage)
    end
  rescue => e
    handleError(e)
    m.reply(@errorMessage)
    return nil
  end

  def clearRecurring(m)
    m.origin.timer.deleteEventOccurrence('recurring')
    m.reply(@clearRecurringMessage)
  end

  def clearReminders(m)
    m.origin.timer.deleteEventType('reminder')
    m.reply(@clearAllMessage)
  end

  def clearMyReminders(m)
    m.origin.timer.deleteReminderUser(m.sender)
    m.reply(@clearPersonalMessage)
  end

  # Consider chronic gem for relative time parsing
  def parseRemindTime(time)
    timeUnit = time[/[a-z]+$/i]
    timeDigit = time[/[0-9\.]+/]

    if timeUnit.match(/(^s$|seconds?|secs?)/)
    elsif timeUnit.match(/(m|minutes?|mins?)/)
      timeDigit = timeDigit.to_f * 60
    elsif timeUnit.match(/(h|hrs?|hours?)/)
      timeDigit = timeDigit.to_f * 60 * 60
    elsif timeUnit.match(/(d|days?)/)
      timeDigit = timeDigit.to_f * 24 * 60 * 60
    end

    remindTime = timeDigit.to_i

    return remindTime
  end
end