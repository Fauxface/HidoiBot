# Ng Guoyou
# Wserver.rb
# This plugin returns selected information from a HTTP header.

class Wserver < BotPlugin
  def initialize
    require 'uri'
    require 'net/http'

    # Authorisations
    @reqWserverAuth = 0

    # Required plugin stuff
    name = self.class.name
    @hook = "wserver"
    processEvery = false
    help = "Usage: #{@hook} <term>\nFunction: Detects server software of a given address from its header."
    super(name, @hook, processEvery, help)
  end

  def main(m)
    m.reply(detectServer(m)) if m.authR(@reqWserverAuth)

    return nil
  rescue => e
    m.reply(e.to_s)
    handleError(e)
    return nil
  end

  def detectServer(m)
    host = m.args[0]
    http = Net::HTTP.new(host)
    http.read_timeout = 20
    res = http.head("/")

    case res.class
    when Net::HTTPRedirection, Net::HTTPMovedPermanently
      rs = "#{host} redirects to #{res['location']} (#{res.code} #{res.message} - #{res['server']})"
    else
      rs = "#{host} (#{res.code} #{res.message} - #{res['server']})"
    end

    return rs
  end
end