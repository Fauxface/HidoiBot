class WolframAlpha < BotPlugin
    require 'open-uri'
    require 'nokogiri' # gem
    
    def initialize
        @apiKey = 'RKYYT3-V4GE3WJV23'
        
        # Authorisations
        @reqWolframAuth = 0
        
        # Strings
        @noAuthMsg = "You are not authorised for this."
        @noResultsMsg = "No results."
        
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
        @givenLevel = data["authLevel"]
        
       if checkAuth(@reqWolframAuth)
            case mode
            when 'all'
                return sayf(wolfram(searchTerm, 20))
            else
                return sayf(wolfram(searchTerm))
            end
        else
            return sayf(@noAuthMsg)
        end
    rescue => e
        handleError(e)
        return nil
    end
    
    def wolfram(searchterm, limit=3)
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
                rs = @noResultsMsg
            end
        else
            rs = formatWolframOutput(ra, limit)
        end
        
        return rs
    rescue => e
        return sayf(@noResultsMsg)
    end
    
    def formatWolframInput(searchterm)
        #Entirely horrible
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
        rs = String.new
        
        for i in 0..limit
            if ra[i] == nil
                # If it's all screwed up
            elsif ra[i].size == 1
                # If title only
                rs += "#{bold(ra[i])}\n"
            elsif ra[i][1] != nil
                # If contains data
                data = ra[i][1]
                data.gsub!("\n", "\n   ") #Create formatted newlines
                rs += "#{bold(ra[i][0])}\n   #{data}\n"
            end
        end
        
        if ra.size > limit
            rs += "\n#{ra.size - limit} sections omitted. Use wolfram all <term> to display all available pods."
        end
        
        return rs
    rescue => e
        handleError(e)
        return sayf(@noResultsMsg)
    end
end