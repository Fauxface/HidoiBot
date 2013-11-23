class Fixnum
  def ordinalize
    if (11..13).include?(self % 100)
      "#{self}th"
    else
      case self % 10
      when 1; "#{self}st"
      when 2; "#{self}nd"
      when 3; "#{self}rd"
      else "#{self}th"
      end
    end
  end
end

class DDate < BotPlugin
  def initialize
    # Authorisations
    @reqAuth = 0

    # Required plugin stuff
    name = self.class.name
    @hook = "ddate"
    processEvery = false
    help = "Usage: #{@hook} <short>\nFunction: All hail Discordia."
    super(name, @hook, processEvery, help)
  end

  def main(m)
    case m.mode
    when 'short'
      m.reply(DiscordianDate.new(Date.today, true)) if m.authR(@reqAuth)
    else
      m.reply(DiscordianDate.new) if m.authR(@reqAuth)
    end

    return nil
  rescue => e
    handleError(e)
    return nil
  end

  class DiscordianDate
    def initialize(date=Date.today, short_form=false)
      @days_in_season = 73
      @year_offset = 1166
      @weekdays = [
        {
          long_name: "Sweetmorn",
          abbreviation: "SM"
        },
        {
          long_name: "Boomtime",
          abbreviation: "BT"
        },
        {
          long_name: "Pungenday",
          abbreviation: "PD"
        },
        {
          long_name: "Prickle-Prickle",
          abbreviation: "PP"
        },
        {
          long_name: "Setting Orange",
          abbreviation: "SO"
        }
      ]
      @seasons = [
        {
          long_name: 'Chaos',
          abbreviation: 'Chs',
          apostle_holyday: 'Mungday',
          season_holyday: 'Chaoflux'
        },
        {
          long_name: 'Discord',
          abbreviation: 'Dsc',
          apostle_holyday: 'Mojoday',
          season_holyday: 'Discoflux'
        },
        {
          long_name: 'Confusion',
          abbreviation: 'Cfn',
          apostle_holyday: 'Syaday',
          season_holyday: 'Confuflux'
        },
        {
          long_name: 'Bureaucracy',
          abbreviation: 'Bcy',
          apostle_holyday: 'Zaraday',
          season_holyday: 'Bureflux'
        },
        {
          long_name: 'The Aftermath',
          abbreviation: 'Afm',
          apostle_holyday: 'Maladay',
          season_holyday: 'Afflux'
        }
      ]

      @year = date.year + @year_offset

      if date.leap? && date.yday >= 60
        @day_of_year = date.yday - 1
      else
        @day_of_year = date.yday
      end

      @season_day = @day_of_year % @days_in_season
      season_index = (@day_of_year / @days_in_season).to_i

      if @season_day == 0
        # Count from 1
        @season_day = @days_in_season
        season_index -= 1
        season_index = @seasons.length - 1 if season_index < 0
      end

      day_index = (@day_of_year - 1) % 5

      form = short_form ? :abbreviation : :long_name

      @weekday = @weekdays[day_index][form]
      @season  = @seasons[season_index][form]
      @holyday = @seasons[season_index][:apostle_holyday] if @season_day == 5
      @holyday = @seasons[season_index][:season_holyday]  if @season_day == 50
      @st_tibs = (date.leap? && date.month == 2 && date.day == 29)
    end

    def to_s
      if @st_tibs
        "Today is St. Tib's Day, in the YOLD #{@year}"
      elsif @holyday
        "Today is #{@holyday}, in the YOLD #{@year}"
      else
        "Today is #{@weekday}, the #{@season_day.ordinalize} day of #{@season} in the YOLD #{@year}"
      end
    end
  end
end