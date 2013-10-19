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
    DAYS_IN_SEASON = 73
    YEAR_OFFSET = 1166
    WEEKDAYS = [
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
    SEASONS = [
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

    def initialize(date=Date.today, short_form=false)
      @year = date.year + YEAR_OFFSET
      @st_tibbs = (date.leap? && date.month == 2 && date.day == 29)

      if date.leap? && date.yday >= 60
        @day_of_year = date.yday - 1
      else
        @day_of_year = date.yday
      end

      @season_day = @day_of_year % DAYS_IN_SEASON
      season_index = (@day_of_year / DAYS_IN_SEASON).to_i

      if @season_day == 0
        # Count from 1
        @season_day = DAYS_IN_SEASON
        season_index -= 1
        season_index = SEASONS.length - 1 if season_index < 0
      end

      day_index = (@day_of_year - 1) % 5

      @weekday = short_form ? WEEKDAYS[day_index][:abbreviation]   : WEEKDAYS[day_index][:long_name]
      @season  = short_form ? SEASONS[season_index][:abbreviation] : SEASONS[season_index][:long_name]
      @holyday = SEASONS[season_index][:apostle_holyday] if @season_day == 5
      @holyday = SEASONS[season_index][:season_holyday]  if @season_day == 50
    end

    def to_s
      if @st_tibbs
        "Today is St. Tibb's Day, in the YOLD #{@year}"
      elsif @holyday
        "Today is #{@holyday}, in the YOLD #{@year}"
      else
        "Today is #{@weekday}, the #{@season_day.ordinalize} day of #{@season} in the YOLD #{@year}"
      end
    end
  end
end