class HeatIndex < BotPlugin
    def initialize
        # Required plugin stuff
        name = self.class.name
        hook = 'hi'
        processEvery = false
        help = "Usage: #{hook} <tempC> <humidity%>\nFunction: Calculates heat index for given temperature and humidity."
        super(name, hook, processEvery, help)
    end

    def main(data)
        tempC = arguments(data)[0]
        humidity = arguments(data)[1]
        return sayf(calcHeatIndex(tempC.to_f, humidity.to_f))
    rescue => e
        handleError(e)
        return nil
    end
    
    def calcHeatIndex(tempC, humidity) 
        tempF = tempC * 9 / 5 + 32
        con1, con2, con3, con4, con5, con6, con7, con8, con9 = -42.379, 2.04901523, 10.14333127, -0.22475541, -6.83783 * 10**-3, -5.481717 * 10**-2, 1.22874 * 10**-3, 8.5282 * 10**-4, -1.99 * 10**-6
        hiF = con1 + con2 * tempF + con3 * humidity + con4 * tempF * humidity + con5 * tempF**2 + con6 * humidity**2 + con7 * tempF**2 * humidity + con8 * tempF * humidity**2 + con9 * tempF**2 * humidity**2
        hiC = (hiF - 32) * 5 / 9
        return "Heat Index: #{hiC.to_s[0..5]}"
    end
end