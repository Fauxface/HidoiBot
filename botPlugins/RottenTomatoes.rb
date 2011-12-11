# Ng Guoyou
# RottenTomatoes.rb
# A Rotten Tomatoes API interface. Does searching for movie ratings.

class RottenTomatoes < BotPlugin
  require 'json'
  require 'open-uri'

  def initialize
    @apiKey = '2rr8cpyb6zuxvkcc28gma85r'
    @apiCall = "http://api.rottentomatoes.com/api/public/v1.0.json?apikey=#{@apiKey}"
    @apiCallMovies = "http://api.rottentomatoes.com/api/public/v1.0/movies.json?apikey=#{@apiKey}"
    @apiCallQuery = "&q="

    # Authorisations
    @reqRottenAuth = 0

    # Strings
    @noResultsMsg = "No results were found."

    # Required plugin stuff
    name = self.class.name
    @hook = "rotten"
    processEvery = false
    help = "Usage: #{@hook} *(rating) <term>\nFunction: Returns movie information from Rotten Tomatoes."
  end

  def main(m)
    if m.authR(@reqRottenAuth)
      case m.mode
      when /(ratings?|score)/
        movie = m.shiftWords(2)
        m.reply(getOnlyMovieRating(movie))
      else
        movie = m.shiftWords(1)
        m.reply(getMovieSummary(movie))
      end
    end

    return nil
  rescue => e
    handleError(e)
    return nil
  end

  def call(query = 'inception')
    # Calls RottonTomatoes API
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
    mov = call(movie)

    if mov["total"].to_i <= 0
      return @noResultsMsg
    else
      mov = mov["movies"][0]
      basics = bold(getMovieBasic(mov))
      synopsis = getMovieSynopsis(mov)
      ratings = getMovieRatings(mov)

      return "#{basics}\n#{synopsis}\nRatings - #{ratings}"
    end
  end

  def getOnlyMovieRating(movie)
    mov = call(movie)

    if mov["total"].to_i <= 0
      return @noResultsMsg
    else
      mov = mov["movies"][0]
      basics = bold(getMovieBasic(mov))
      ratings = getMovieRatings(mov)

      return "#{basics}\n#{ratings}"
    end
  end

  def getMovieBasic(mov)
    return "#{mov["title"]} (#{mov["year"]})"
  end

  def getMovieSynopsis(mov)
    return "#{mov["synopsis"]}"
  end

  def getMovieRatings(mov)
    return "Critics: #{mov["ratings"]["critics_score"]}, Audience: #{mov["ratings"]["audience_score"]}"
  end

  def formatInput!(s)
    s.gsub!(" ", '+')
  end
end