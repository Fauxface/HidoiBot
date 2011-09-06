# Ng Guoyou
# Humidex.rb
# Calculates the humidex given the air temperature in C and the dew point in C.
# http://en.wikipedia.org/wiki/Humidex

class Humidex < BotPlugin
  def initialize
    # Required plugin stuff
    name = self.class.name
    hook = 'humidex'
    processEvery = false
    help = "Usage: #{hook} <airTempC> <dewPointC>\nFunction: Calculates humidex for given air temperature and dew point."
    super(name, hook, processEvery, help)
  end

  def main(data)
    airTempC = arguments(data)[0]
    dewPointC = arguments(data)[1]

    return sayf(calcHumidex(airTempC.to_f, dewPointC.to_f))
  rescue => e
    handleError(e)
    return nil
  end

  def calcHumidex(airTempC, dewPointC)
    # http://en.wikipedia.org/wiki/Humidex
    dewPointK = dewPointC + 273.15
    e = 6.11 * Math::E**(5417.7530 * ((1/273.16) - (1/dewPointK)))
    humid = airTempC + (0.5555)*(e - 10)

    if humid > 54
        hstatus = "It is time for a heatstroke."
    elsif humid > 45
        hstatus = "The heat is dangerous."
    elsif humid > 40
        hstatus = "Great discomfort is expected."
    elsif humid > 30
        hstatus = "Some discomfort is expected."
    else
        hstatus = "No discomfort is expected."
    end

    return "Humidex: #{(humid).to_s[0..5]}; #{hstatus}"
  end
end