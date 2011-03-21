# Ported from HidoiBot1
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

    def main(data)
        doc = Nokogiri::HTML(open('http://weather.nea.gov.sg/ForecastToday.aspx'))
        forecast = doc.search('//span[@id="ctl00_ctl00_cphBody_cphContent_lblForecast"]').inner_text
        temperature = doc.search('//span[@id="ctl00_ctl00_cphBody_cphContent_lblTodayTemperature"]').inner_text
        humidity =  doc.search('//span[@id="ctl00_ctl00_cphBody_cphContent_lblTodayHumidity"]').inner_text
        validtime = doc.search('//div[@id="ctl00_ctl00_divTodayValidTime"]').inner_text
        temperature.gsub!('Â','')
        avtemp = (temperature[0..1].to_f + temperature[3..4].to_f)/2
        avhumi = (humidity[0..1].to_f + humidity[3..4].to_f)/2
        returnstring = "#{forecast} #{temperature} @ #{humidity} humidity. Valid #{validtime} +800GMT."
        
        return "say '#{returnstring}'"
    rescue => e
        handleError(e)
        return nil
    end
end