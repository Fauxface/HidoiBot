class WolframAlpha < BotPlugin
    require 'open-uri'
    require 'nokogiri' # gem
    
    def initialize
        @apiKey = 'RKYYT3-V4GE3WJV23'
    
        # Required plugin stuff
        name = self.class.name
        hook = "wolfram"
        processEvery = false
        help = "Usage: #{hook} <*all> <searchterm>\nFunction: Returns Wolfram|Alpha results in text form."
        super(name, hook, processEvery, help)  
    end

    def main(data)
        # Yes, I am aware of the fact that this is an atrociously written plugin
        mode = arguments(data)[0]
        searchTerm = stripTrigger(data)
        
        case mode
            when 'all'
                return "say '#{wolfram(searchTerm, 20)}'"
            else
                return "say '#{wolfram(searchTerm)}'"
        end
    rescue => e
        handleError(e)
        return nil
    end
    
    def wolfram(searchterm, limit=3)
		begin
			ra = Array.new
            
            puts "Wolfram|Alpha: searching for #{searchterm}"
			formatWolframInput(searchterm)
            
			rawResult = Nokogiri::XML(open("http://api.wolframalpha.com/v2/query?appid=#{@apiKey}&format=plaintext&input=\'#{searchterm}\'"))
			pods = rawResult.search("//pod")
			podTitles = rawResult.search("//pod['title']")
			relatedExamplesCount = rawResult.search("//relatedexamples")
			indvRelatedExamples = relatedExamplesCount.search("//relatedexamples/relatedexample")
		
			for i in 0..(pods.size - 1)
				ra[i] = [podTitles[i]['title'].to_s.gsub("\n ", '').strip, podTitles[i].inner_text.gsub("\n ", '').strip]
			end
			
			if ra[0] == nil
				numberOfRelatedExamples = relatedExamplesCount[0]['count'].to_i
                
				if numberOfRelatedExamples > 0
                    # If we have no result but at least one related example, try the first on the list
					searchterm = indvRelatedExamples[0]['input']
					rs = wolfram(searchterm, limit + 1)
				else
					rs = "No results." 
				end
			else
				rs = formatWolframOutput(ra, limit)
			end		
				
			return rs
		rescue => e
			return 'say "WolframAlpha: Search term not found?"'
		end
	end
	
	def formatWolframInput(searchterm)
		#Horrible
		#'%' has to go first or it'll substitute the others
		searchterm.gsub!('%', '%25')
		searchterm.gsub!('+', '%2B')
		searchterm.gsub!(',', '%2C')
		searchterm.gsub!(' ', '%20')
		searchterm.gsub!('/', '%2F')
		searchterm.gsub!('@', '%40')
		searchterm.gsub!('#', '%23')
		searchterm.gsub!('$', '%24')
		searchterm.gsub!('^', '%5E')
		searchterm.gsub!('&', '%26')
		searchterm.gsub!('=', '%3D')
		searchterm.gsub!(':', '%3A')
		searchterm.gsub!(';', '%3B')
		searchterm.gsub!('"', '%22')
		searchterm.gsub!("\\", '%5C')
		searchterm.gsub!('|', '%7C')
		searchterm.gsub!('{', '%7B')
		searchterm.gsub!('}', '%7D')
		searchterm.gsub!('[', '%5B')
		searchterm.gsub!(']', '%5D')
		searchterm.gsub!('<', '%3C')
		searchterm.gsub!('>', '%3E')
		searchterm.gsub!('>', '%3F')
		searchterm.gsub!('`', '%60')
		return searchterm
	end
	
	def formatWolframOutput(ra, limit)
		# Also horrible
		begin
			rs = String.new
			
			for i in 0..limit
				# If it's all screwed up
				if ra[i] == nil
				# If title only
				elsif ra[i].size == 1
					rs += "\x02" + ra[i] + "\x02" + "\n"
				# If contains data
				elsif ra[i][1] != nil
					# Somehow it doesn't seem to work otherwise and I'm too lazy
					data = ra[i][1]
					#Create formatted newlines
					data.gsub!("\n", "\n   ")
					rs += "\x02" + ra[i][0] + "\x02" + "\n   " + data + "\n"
				end
			end
            
            if ra.size > limit
                rs += "\n#{ra.size - limit} sections omitted. Use wolfram all <term> to display all pods."
            end
            
			return rs
		rescue => e
            handleError(e)
			return 'say "formatWolframOutput: Search term not found?"'
		end
	end
end