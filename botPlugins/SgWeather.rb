# encoding: utf-8
class SgWeather < BotPlugin
    require 'open-uri'
    require 'nokogiri' # gem
    
    def initialize    
        # Required plugin stuff
        name = self.class.name
        hook = "sgweather"
        processEvery = false
        help = "Returns weather forecast for Singapore, taken from NEA's website."
        super(name, hook, processEvery, help)
    end

    # Ported from HidoiBot1
    def main(data)
        return sayf(scrapeWeather)
    rescue => e
        handleError(e)
        return nil
    end
    
    def scrapeWeather
        doc = Nokogiri::HTML(open('http://weather.nea.gov.sg/ForecastToday.aspx'))
        
        forecast = doc.search('//span[@id="ctl00_ctl00_cphBody_cphContent_lblForecast"]').inner_text
        temperature = doc.search('//span[@id="ctl00_ctl00_cphBody_cphContent_lblTodayTemperature"]').inner_text
        temperature.gsub!('Â','')        
        humidity =  doc.search('//span[@id="ctl00_ctl00_cphBody_cphContent_lblTodayHumidity"]').inner_text
        validTime = doc.search('//div[@id="ctl00_ctl00_divTodayValidTime"]').inner_text\
        
        avTemp = (temperature[0..1].to_f + temperature[3..4].to_f)/2
        avHumi = (humidity[0..1].to_f + humidity[3..4].to_f)/2
        
        rs = "#{forecast} #{temperature} @ #{humidity} humidity. Valid #{validTime} +800GMT. Heat Index: #{calcHeatIndex(avTemp, avHumi)}"
    
        return rs
    end
    
    def calcHeatIndex(tempC, humidity) 
		tempF = tempC * 9 / 5 + 32
		con1, con2, con3, con4, con5, con6, con7, con8, con9 = -42.379, 2.04901523, 10.14333127, -0.22475541, -6.83783 * 10**-3, -5.481717 * 10**-2, 1.22874 * 10**-3, 8.5282 * 10**-4, -1.99 * 10**-6
		hiF = con1 + con2 * tempF + con3 * humidity + con4 * tempF * humidity + con5 * tempF**2 + con6 * humidity**2 + con7 * tempF**2 * humidity + con8 * tempF * humidity**2 + con9 * tempF**2 * humidity**2
		hiC = (hiF - 32) * 5 / 9
		return "#{hiC.to_s[0..3]}°C"
	end
end