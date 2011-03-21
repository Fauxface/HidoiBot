# Ported from HidoiBot1
class WorldOfWarcraft < BotPlugin
    require 'open-uri'
    require 'nokogiri'
    
    def initialize
        # Required plugin stuff
        name = self.class.name
        hook = "wow"
        processEvery = false
        help = "Usage: #{hook} <realm>\nFunction: Returns status of specified realm."
        super(name, hook, processEvery, help)
    end
    
    # Ported from HidoiBot1
    def main(data)
        realm = stripTrigger(data)
        return "say '#{realmStatus(realm)}'"
    rescue => e
        handleError(e)
        return nil
    end
    
    def realmStatus(realm)
		begin
			doc = Nokogiri::HTML(open('http://us.battle.net/wow/en/status'))
			realmNames = doc.xpath("//td[@class='name']").to_a
			realmPopulations = doc.xpath("//td[@class='population']").to_a
			realmStatus = doc.xpath("//td[@class='status']")
			realmQueues = doc.xpath("//td[@class='queue']")
			realmLocales = doc.xpath("//td[@class='locale']").to_a
			realmTypes = doc.xpath("//td[@class='type']")
			
			for i in 0..realmNames.size
				realmnumber = i if realmNames[i].to_s.downcase.include?(realm.downcase)
			end
			
			if realmnumber == nil
				rs = 'No such realm was found.'
			else
				rs = "#{realmNames[realmnumber].inner_text} (#{realmTypes[realmnumber].inner_text.gsub!(/[\(\)]/,'')}, #{realmLocales[realmnumber].inner_text}, #{realmPopulations[realmnumber].inner_text}): #{realmStatus[realmnumber]['data-raw'].capitalize!}"
				rs.gsub!(/(\\n|	)/,'')
				rs.gsub!("\n",'')
				
				if realmQueues[realmnumber]['data-raw'] == 'true'
					rs += ' - There is a queue for this realm.'
				end
			end
			return rs
		rescue => e
			puts e
			return "realmStatus: #{e}"
		end
	end
end