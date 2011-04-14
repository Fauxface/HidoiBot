class RottenTomatoes < BotPlugin
    require 'json'
    #require 'json/pure'
    require 'open-uri'
    
    def initialize
        @apiKey = '2rr8cpyb6zuxvkcc28gma85r'
        @apiCall = "http://api.rottentomatoes.com/api/public/v1.0.json?apikey=#{@apiKey}"
        @apiCallMovies = "http://api.rottentomatoes.com/api/public/v1.0/movies.json?apikey=#{@apiKey}"
        @apiCallQuery = "&q="
        
        # Authorisations
        @reqRottenAuth = 0
        
        # Strings
        @noAuthMsg = "You are not authorised for this."
        @noResultsMsg = "No results were found."
        
        # Required plugin stuff
        name = self.class.name
        @hook = "rotten"
        processEvery = false
        help = "Usage: #{@hook} *(rating) <term>\nFunction: Returns movie information from Rotten Tomatoes."
        
        begin
            # Check gem availability
            gem "json"
            super(name, @hook, processEvery, help)
        rescue GEM::LoadError
            puts "botPlugin RottenTomatoes load error: gem json is not installed."
            puts "To install, type 'gem install json' or 'gem install json_pure'"
        end       
    end

    def main(data)
        @givenLevel = data["authLevel"]
        
        if checkAuth(@reqRottenAuth)
            mode = arguments(data)[0]
            
            case mode
                when /(ratings?|score)/
                    movie = stripWordsFromStart(data['message'], 2)
                    return sayf(getOnlyMovieRating(movie))
                else
                    movie = stripWordsFromStart(data['message'], 1)
                    return sayf(getMovieSummary(movie))
            end
        else
            return sayf(@noAuthMsg)
        end
    rescue => e
        handleError(e)
        return nil
    end
    
    def call(query = 'inception')
        # doc is a Hash with keys: total, movies, links, links_templates
        #
        # movies is an Array of Hashes
        #
        # List of keys for movies
        # id = m["id"]
        # title = m["title"]
        # year = m["year"]
        # runtime = m["runtime"]
        # releaseTheater = m["release_dates"]["theater"]
        # releaseDVD = m["release_dates"]["dvd"]
        # ratingsCritics = m["ratings"]["critics"]
        # ratingsAudience = m["ratings"]["audience"]
        # synopsis = m["synopsis"]
        # abridgedCast = m["abridged_cast"]
        # rottenTomatoesLink = m["links"]["alternate"]
    
        formatInput!(query)
        queryString = "#{@apiCallMovies}#{@apiCallQuery}#{query}"
        puts 'RottenTomatoes: ' + queryString
        jsondoc = open(queryString).read
        doc = JSON.parse(jsondoc)
        
        return doc
    end
    
    # Modes
    def getMovieSummary(movie)
        m = call(movie)
        
        if m["total"].to_i <= 0
            return @noResultsMsg
        else
            m = m["movies"][0]
            basics = bold(getMovieBasic(m))
            synopsis = getMovieSynopsis(m)
            ratings = getMovieRatings(m)
            
            return "#{basics}\n#{synopsis}\nRatings - #{ratings}"
        end
    end
    
    def getOnlyMovieRating(movie)
        m = call(movie)
        
        if m["total"].to_i <= 0
            return @noResultsMsg
        else
            m = m["movies"][0]
            basics = bold(getMovieBasic(m))
            ratings = getMovieRatings(m)
            
            return "#{basics}\n#{ratings}"
        end
    end
    
    # Constructors
    def getMovieBasic(m)
        return "#{m["title"]} (#{m["year"]})"
    end
    
    def getMovieSynopsis(m)
        return "#{m["synopsis"]}"
    end
    
    def getMovieRatings(m)
        return "Critics: #{m["ratings"]["critics_score"]}, Audience: #{m["ratings"]["audience_score"]}"
    end
    
    def formatInput!(data)
        data.gsub!(" ", '+')
    end
end