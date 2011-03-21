# Config file for bot behaviour

def botSettings
    # Trigger: what the bot will respond to, single character
    @trigger = '~'

    # pingTimeout: Time to wait after pinging the server before declaring a timeout, in seconds
    @pingTimeout = 120

    # pingInterval: How often the bot pings the server, in seconds
    @pingInterval = 300

    # serverConnectTimeout: How long the bot will wait after a connect attempt before declaring a timeout, in seconds
    @serverConnectTimeout = 60

    # maxMessageLength: The maximum number of characters you can send to the server in a single line, in seconds
    @maxMessageLength = 400

    # messageSendDelay: How long the bot will wait between sending multiple lines, in seconds
    @messageSendDelay = 0.5
end