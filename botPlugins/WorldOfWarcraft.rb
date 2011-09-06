# Ng Guoyou
# WorldOfWarcraft.rb
# Checks realm status. Information is scraped off Blizzard's site.

class WorldOfWarcraft < BotPlugin
  require 'open-uri'
  require 'nokogiri'

  def initialize
    # Authorisations
    @reqWowAuth = 0

    # Strings
    @noAuthMsg = "You are not authorised for this."
    @noRealmMsg = "No such realm was found."
    @queueMsg = "There is a queue for this realm."

    # Required plugin stuff
    name = self.class.name
    hook = ["wow", "realm"]
    processEvery = false
    help = "Usage: #{hook} <realm>\nFunction: Returns status of specified realm."
    super(name, hook, processEvery, help)
  end

  def main(data)
    @givenLevel = data["authLevel"]

    return authCheck(@reqWowAuth) ? sayf(realmStatus(stripTrigger(data))) : sayf(@noAuthMsg)
  rescue => e
    handleError(e)
    return nil
  end

  def realmStatus(realm)
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
      rs = @noRealmMsg
    else
      name = realmNames[realmnumber].inner_text
      type = realmTypes[realmnumber].inner_text.gsub!(/[\(\)]/,'')
      locale = realmLocales[realmnumber].inner_text
      population = realmPopulations[realmnumber].inner_text
      status = realmStatus[realmnumber]['data-raw'].capitalize!

      rs = "#{name} (#{type}, #{locale}, #{population}): #{bold(status)}"
      rs.gsub!(/(\\n|\t)/,'')
      rs.gsub!("\n",'')

      if realmQueues[realmnumber]['data-raw'] == 'true'
        rs += " - #{@queueMsg}"
      end
    end
    return rs
  rescue => e
    handleError(e)
    return nil
  end
end