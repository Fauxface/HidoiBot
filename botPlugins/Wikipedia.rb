# Ported from HidoiBot1
class Wikipedia < BotPlugin
    def initialize
        # Required plugin stuff
        name = self.class.name
        hook = "wiki"
        processEvery = false
        help = "Usage: #{hook} (*plot) <term>\nFunction: Returns Wikipedia result for specified search term. Use #{hook} plot <term> to return the second section, which is normally the plot synopsis if there is one."
        super(name, hook, processEvery, help)
    end

    def main(data)
        mode = arguments(data)[0]
        searchterm = stripTrigger(data)
        
        case mode
            when 'plot'
                searchterm = arguments(data)[1]
                return "say ('#{wiki(searchterm, 1)}')"
            else
                return "say ('#{wiki(searchterm)}')"
        end
    rescue => e
        handleError(e)
        return nil
    end
    
    def wiki(searchterm, *section)\
        termToUse = String.new
        maxSectionLength = 2500
		section[0] = 0 if section[0] == nil
		searchterm.gsub!(" ","_")
		searchDoc = open("http://en.wikipedia.org/w/api.php?action=opensearch&search=#{searchterm}").to_a
		searchDoc = searchDoc[0].gsub(/[\[\]"\\]/,"")
		searchDoc = searchDoc.split(",")
		termToUse = searchDoc[1]
		termToUse.gsub!(" ","%20")
		doc = Nokogiri::HTML(open("http://en.wikipedia.org/w/api.php?action=query&prop=revisions&titles=#{termToUse}&rvprop=content&rvsection=#{section[0]}&format=xml"))
		rs = doc.xpath("//rev").inner_text
		stripWikiMarkup(rs)
        escapeSyntax(rs)
		if rs.length > maxSectionLength
			return "#{rs[0..maxSectionLength]}\nResult truncated; section is too long."
		else
            puts rs
			return rs
		end
	end
		
	def stripWikiMarkup(s)
		s.gsub!(/<ref>.+<\/ref>/m, '') #References
		s.gsub!(/{{Infobox .+?}}/m, '') #Infoboxes
		#s.gsub!(/{{.+\|/, '') #Selective Templates
		#s.gsub!(/\[\[.+?\|/, '') #Links To Different Stuff
		#s.gsub!(/{{.+}}/m,'') #Templates
		s.gsub!('&nbsp', ' ')
		s.gsub!(/===?/, '=') #Section Headings
		s.gsub!('----', '/n----/n') #Horizontal Lines
		s.gsub!(':', '	') #Indents
		s.gsub!('<br />', '/n') #Newlines
		s.gsub!(/(\[\[|\]\]|\\|''|'''''|{{|}}|\|\]\])/, '') #Markup Nonsense
        s.gsub!(/\|/, '')
		return s
	end
end