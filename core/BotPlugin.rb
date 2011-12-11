# encoding:utf-8
# Ng Guoyou
# BotPlugin.rb
# Basic BotPlugin class. Contains common methods and initialisation mapping code.

class BotPlugin
  require 'json'

  def initialize(botModuleName, hook, processEvery, *help)
    # Initialises plugins and maps their hooks so they can be called using commands.
    # The plugin will extend BotPlugin, and call super(botModuleName, hook, processEvery, *help) in its own initialise method
    # or other method that works
    #
    # TODO: Make a doBotsMapping method, so support for multiple servers is handled
    #
    # Params:
    # +botModuleName+:: Name of the plugin (and the class, as well -- self.name).
    # +hook+:: Trigger(s) to map, can be a +String+ or an +Array+ of +Strings+.
    # +processEvery+:: +Boolean+. Whether every PRIVMSG received is passed to this plugin
    # +help+:: Optional +String+ containing help and usage information. Used for the help command.

    if hook.class == Array && hook.size > 1
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

  ###################
  # Text prepration #
  ###################

  def escapeSyntax(s)
    # Escapes s for SQL/eval.
    # !-Bad-! Use m.origin.methodToCall instead to avoid eval errors.
    # Use this if you are getting syntax errors in IRC from breaking eval
    # Use escapeSyntaxHard for more hardcore escapism action
    #
    # Params:
    # +s+:: String to escape.

    if s.class == String
      s = s.gsub(/[\\]/, '\\\\\\')
      s = s.gsub(/[']/, '\\\\\'')
      s = s.gsub(/["]/, '\\\\\"')
    end

    return s
  end

  def escapeSyntaxHard(s)
    # Escapes s harder for SQL/eval.
    # !-Bad-! Use prepared statements instead for SQL
    # http://weblog.jamisbuck.org/2004/12/19/sqlite3-bindings-for-ruby
    #
    # Params:
    # +s+:: String to escape.

    s = s.gsub(/['"]/, '`')
  end

  def sayf(s)
    # Formats a string to be used in IRC.runPlugin's eval().
    # Preferably use `m.reply` in plugins
    # Formats a string in prepration for returns to the main bot
    #
    # Params:
    # +s+:: Object to format. Will be converted into a String.

    return "say '#{s}'"
  end

  # Alias for rbot style
  alias :echo :sayf

  #######################
  # IRC text formatting #
  #######################

  def bold(s)
    # Prepend and append IRC control code for bold to +s+.
    #
    # Params:
    # +s+:: String to format.

    boldChar = "\002"
    return prependAppend(s, boldChar)
  end

  def italic(s)
    # Prepend and append IRC control code for italic to +s+.
    # Or oblique, whichever floats your boat
    #
    # Params:
    # +s+:: String to format.

    italicChar = "\011"
    return prependAppend(s, italicChar)
  end

  def underline(s)
    # Prepend and append IRC control code for underline to +s+.
    #
    # Params:
    # +s+:: String to format.

    underlineChar = "\037"
    return prependAppend(s, underlineChar)
  end

  def colour(s, textColour, highlightColour=nil)
    # Prepend and append IRC control code for colour and highlight to +s+.
    #
    # Params:
    # +s+:: String to format.
    # +textColour+:: An IRC colour code. Will be checked for validity.
    # +highlightColour+:: An IRC colour code. Will be checked for validity. Defaults to no highlight.

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
    return prependAppend(s, colourChar)
  rescue => e
    handleError(e)
    return s
  end

  def isColour?(colourCode)
    # Checks colourCode for range 0-15
    #
    # Params:
    # +colourCode+:: Colour code to check.

    /^(0?[0-9]|[0-1][0-5]?)$/ === "#{colourCode}" ? true : false
  end

  def reverseColour(s)
    # Prepend and append IRC control code for reverse colour to +s+.
    #
    # Params:
    # +s+:: String to format.

    reverseChar = "\026"
    return prependAppend(s, reverseChar)
  end

  # Alias for the AMERICANS
  alias :color :colour
  alias :isColor? :color
  alias :reverseColor :reverseColour

  def clearCodes
    # Returns IRC control code for normal
    normalChar = "\017"
    return normalChar
  end

  def prependAppend(s, word)
    # Helper method for insertion of IRC control codes. Adds +word+ to the beginning and end of +s+.
    #
    # Params:
    # +s+:: String to format.
    # +word+:: String to add to beginning and end of s.

    s.insert(0, word)
    s.insert(s.size, word)

    return s
  end

  def decimalPlace(f, p=2)
    # Returns f rounded to p decimal places
    raise "Invalid precision" if !p.is_a? Integer
    p = 10 ** p

    return ((f * p).round)/(p.to_f)
  rescue => e
    handleError(e)
    return f
  end

  def humaniseSeconds(second)
    # Converts seconds in integer to this format, with proper grammar:
    # x years, y months, z, weeks, a days, b hours, c minutes, d seconds
    #
    # Params:
    # +second+:: An integer value of seconds to be "humanised".

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

  ###################
  # Plugin settings #
  ###################

  def loadSettings
    # Loads persistent plugin settings.
    configPath = 'botPlugins/settings/' # Doesn't work as a class/instance variable?
    File.open("#{configPath}/#{@settingsFile}", "a+") { |file|
      @s = JSON.parse(file.read)
    }
  rescue => e
    handleError(e)
  end

  def saveSettings
    # Saves persistent plugin settings.
    configPath = 'botPlugins/settings/' # Doesn't work as a class/instance variable?
    File.open("#{configPath}/#{@settingsFile}", "w") { |file|
      file.puts @s.to_json
    }
  rescue => e
    handleError(e)
  end

  def handleError(e)
    # Handles errors. Prints the error and its backtrace.
    puts e
    puts e.backtrace.join("\n")
  end
end