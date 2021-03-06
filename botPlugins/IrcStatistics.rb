﻿# Ng Guoyou
# IrcStatistics.rb
# This plugin handles everything related to IRC statistics: saving and retrieving user, channel and settings

class IrcStatistics < BotPlugin
  require 'date'

  def initialize
    extend HidoiSQL
    hsqlInitialize
    checkStatsTables

    # Default Persistent Settings
    @s = {
      'tracking' => true
    }

    @settingsFile = "ircStatistics/settings.json"
    loadSettings

    # Authorisations
    @reqConfigAuth = 3
    @reqStatsAuth = 0

    # Strings
    @setOnMessage = "Statistics tracking is now on."
    @setOffMessage = "Statistics tracking is now off."
    @statusOnMessage = "Statistics tracking is currently on."
    @statusOffMessage = "Statistics tracking is currently off."
    @noModeMessage = "I am done looking for nothing."
    @noSeenArgMessage = "Who?"

    # Required plugin stuff
    name = self.class.name
    @hook = ['stats', 'seen']
    processEvery = true
    help = "Usage: #{@hook[0]} (on|off|status|user <nickname>|channel <name>), #{@hook[1]} <nickname>\nFunction: Handles statistics tracking for IRC. Use #{@hook[1]} to determine when a user last spoke."
    super(name, @hook, processEvery, help)
  end

  def main(m)
    if m.processEvery && m.trigger == 'auth'
      # Not learning auth

    elsif m.processEvery != true && m.trigger == @hook[0]
      # If called using 'stats', which is hook[0]
      if m.authR(@reqStatsAuth)
        case m.mode
        when 'on'
          if m.authR(@reqConfigAuth)
            @s['tracking'] = true
            saveSettings
            m.reply(@setOnMessage)
          end
        when 'off'
          if m.authR(@reqConfigAuth)
            @s['tracking'] = false
            saveSettings
            m.reply(@setOffMessage)
          end
        when 'status'
          m.reply(isTracking)
        when 'user'
          m.reply(prettyStat(m, 'user', sanitize(m.args[1], 'user')))
        when 'channel'
          m.reply(prettyStat(m, 'channel', m.args[1]))
        when 'all'
          # Global statistics
        when 'seen'
          m.trigger = @hook[1]
        else
          m.reply(@noModeMessage)
        end
      end

    elsif m.trigger == @hook[1] && m.processEvery != true
      # If called using 'seen', which is hook[1]
      if m.authR(@reqStatsAuth)
        if m.args[0] != nil
          rs = prettyStat(m, 'seen', sanitize(m.args[0], 'user'))
          m.reply(rs)
        else
          m.reply(@noSeenArgMessage)
        end
      end

    elsif @s['tracking'] == true && m.processEvery
      if silentSql("SELECT * FROM stats_channel WHERE name = '#{m.channel}' AND server_group = '#{m.serverGroup}'")[0] == nil && @s['tracking'] == true
        recordNewChannel(m) # If new channel
      else
        updateChannel(m)
      end

      if silentSql("SELECT * FROM stats_user WHERE nickname = '#{m.sender}' AND server_group = '#{m.serverGroup}'")[0] == nil
        recordNewUser(m) # If new user
      else
        updateUser(m)
      end
    end

    return nil
  rescue => e
    handleError(e)
    return nil
  end

  def isTracking
    if @s['tracking'] == true
      return @statusOnMessage
    else
      return @statusOffMessage
    end
  end

  def sanitize(string, mode)
    if mode == 'user'
      string = string.slice(/\A[a-z_\-\[\]\\^{}|`][a-z0-9_\-\[\]\\^{}|`]*\z/i)
    elsif mode == 'channel'
      string = string.slice(/#[a-z_\-\[\]\\^{}|`][a-z0-9_\-\[\]\\^{}|`]*\z/i)
    end

    return string
  end

  def prettyStat(m, mode, term)
    # Formats statistics into a return string
    return "Invalid name." if term == nil

    case mode
    when 'user'
      userData = silentSql("SELECT nickname, last_message, last_message_time, last_message_channel, message_count, character_count, first_seen FROM stats_user WHERE nickname = '#{term}' AND server_group = '#{m.serverGroup}'")[0]

      if userData != nil
        nickname = userData[0]
        lastMessage = userData[1]
        lastMessageTime = Date.parse(userData[2])
        lastMessageChannel = userData[3]
        messageCount = userData[4]
        characterCount = userData[5]
        firstSeen = Date.parse(userData[6])
        daysSinceFirstSeen = (Date.today - firstSeen).to_i
        meanMessageLength = (characterCount/messageCount).to_i

        if daysSinceFirstSeen == 0
          meanMessagesPerDay = messageCount.to_i
        elsif daysSinceFirstSeen > 0
          meanMessagesPerDay = messageCount / daysSinceFirstSeen
        end

        return ("Stats for user #{nickname}:\nLast seen on #{lastMessageTime}, saying \'#{lastMessage.rstrip.lstrip}\' in #{lastMessageChannel}\nMessage count: #{messageCount}, Character count: #{characterCount}, Means: #{meanMessageLength}char/msg, #{meanMessagesPerDay}msg/day\nFirst seen on #{firstSeen}, #{daysSinceFirstSeen} days ago.")
      else
        return "User #{term} was not found. Note: This is case-sensitive."
      end
    when 'channel'
      channelData = silentSql("SELECT name, message_count, character_count, first_seen, last_activity FROM stats_channel WHERE name='#{term}' AND server_group = '#{m.serverGroup}'")[0]

      if channelData != nil
        name = channelData[0]
        messageCount = channelData[1]
        characterCount = channelData[2]
        firstSeen = channelData[3]
        lastActivity = channelData[4]
        daysSinceFirstSeen = (Date.today - Date.parse(firstSeen)).to_i
        meanMessageLength = (characterCount/messageCount).to_i

        if daysSinceFirstSeen == 0
          meanMessagesPerDay = messageCount.to_i
        elsif daysSinceFirstSeen > 0
          meanMessagesPerDay = messageCount / daysSinceFirstSeen
        end

        return ("Stats for channel #{name}:\nLast activity: #{lastActivity}\nMessage count: #{messageCount}, Character count: #{characterCount}, Means: #{meanMessageLength}char/msg, #{meanMessagesPerDay}msg/day\nFirst seen on #{firstSeen}, #{daysSinceFirstSeen} days ago.")
      else
        return "Channel #{term} was not found. Note: This is case-sensitive."
      end
    when 'seen'
      userData = silentSql("SELECT nickname, last_message, last_message_time, last_message_channel FROM stats_user WHERE nickname = '#{term}' AND server_group = '#{m.serverGroup}'")[0]

      if userData != nil
        nickname = userData[0]
        lastMessage = userData[1]
        lastMessageTime = Time.parse(userData[2])
        lastMessageChannel = userData[3]

        lsInSec = Time.now.to_i - lastMessageTime.to_i
        lsaf = humaniseSeconds(lsInSec)

        rs = "#{nickname}: Last seen #{lsaf} ago in #{lastMessageChannel}, saying \'#{lastMessage.rstrip.lstrip}\'."
        rs += "\nNote: Statistics tracking is off -- data might not be accurate." if @s['tracking'] == false

        return rs
      else
        return "User #{term} was not found. Note: This is case-sensitive."
      end
    end
  end

  def recordNewUser(m)
    escapedMessage = escapeSyntaxHard(m.message)
    active = true
    messageCount = 1
    characterCount = escapedMessage.length
    activityCount = 1

    silentSql ("
      INSERT INTO stats_user (
        active,
        server_group,
        nickname,
        hostname,
        realname,
        last_activity,
        last_activity_time,
        last_message,
        last_message_channel,
        last_message_time,
        message_count,
        character_count,
        activity_count,
        first_seen
      ) VALUES (
        '#{active}',
        '#{m.serverGroup}',
        '#{m.sender}',
        '#{m.hostname}',
        '#{m.realname}',
        '#{m.messageType}',
        '#{m.time}',
        '#{escapedMessage}',
        '#{m.channel}',
        '#{m.time}',
        '#{messageCount}',
        '#{characterCount}',
        '#{activityCount}',
        '#{m.time}'
      )
    ")
  end

  def updateUser(m)
    escapedMessage = escapeSyntaxHard(m.message)
    characterCount = escapedMessage.length
    # Oddly, UPDATE stats_user SET ( ... ) WHERE ( ... ) breaks from the parentheses. I am bad at this
    silentSql ("
      UPDATE stats_user SET
        hostname = '#{m.hostname}',
        realname = '#{m.realname}',
        last_activity = '#{m.messageType}',
        last_activity_time = '#{m.time}',
        last_message =  '#{escapedMessage}',
        last_message_channel = '#{m.channel}',
        last_message_time = '#{m.time}',
        message_count = message_count + 1,
        character_count = character_count + #{characterCount},
        activity_count = activity_count + 1
      WHERE
        server_group = '#{m.serverGroup}' AND nickname = '#{m.sender}'
    ")
  end

  def recordNewChannel(m)
    escapedMessage = escapeSyntaxHard(m.message)
    silentSql ("
      INSERT INTO stats_channel (
        name,
        server_group,
        message_count,
        character_count,
        first_seen,
        last_activity
      ) VALUES (
        '#{m.channel}',
        '#{m.serverGroup}',
        '1',
        '#{escapedMessage.length}',
        '#{m.time}',
        '#{m.time}'
      )
    ")
  end

  def updateChannel(m)
    escapedMessage = escapeSyntaxHard(m.message)
    silentSql ("
      UPDATE stats_channel SET
        message_count = message_count + 1,
        character_count = character_count + #{escapedMessage.length},
        last_activity = '#{m.time}'
      WHERE
        server_group = '#{m.serverGroup}' AND name = '#{m.channel}'
    ")
  end

  def checkStatsTables
    # A user's hostname or nickname can change, but to keep it simple we track the nickname
    silentSql ('
      CREATE TABLE IF NOT EXISTS stats_user (
        active boolean NOT NULL DEFAULT true,
        server_group text NOT NULL,
        nickname text NOT NULL,
        hostname text NOT NULL,
        realname text,
        last_activity text,
        last_activity_time timestamp with time zone NOT NULL,
        last_message text,
        last_message_channel, text,
        last_message_time timestamp with time zone NOT NULL,
        message_count integer,
        character_count integer,
        activity_count integer,
        first_seen timestamp with time zone NOT NULL
      )
    ')

    silentSql ('
      CREATE TABLE IF NOT EXISTS stats_channel (
        name text NOT NULL,
        server_group text NOT NULL,
        user_count integer,
        user_count_max integer,
        topic text,
        message_count integer,
        character_count integer,
        last_activity timestamp with time zone,
        first_seen timestamp with time zone NOT NULL
      )
    ')

    silentSql ('
      CREATE TABLE IF NOT EXISTS stats_channel_hour (
        channel_id integer NOT NULL,
        h0 integer NOT NULL DEFAULT 0,
        h1 integer NOT NULL DEFAULT 0,
        h2 integer NOT NULL DEFAULT 0,
        h3 integer NOT NULL DEFAULT 0,
        h4 integer NOT NULL DEFAULT 0,
        h5 integer NOT NULL DEFAULT 0,
        h6 integer NOT NULL DEFAULT 0,
        h7 integer NOT NULL DEFAULT 0,
        h8 integer NOT NULL DEFAULT 0,
        h9 integer NOT NULL DEFAULT 0,
        h10 integer NOT NULL DEFAULT 0,
        h11 integer NOT NULL DEFAULT 0,
        h12 integer NOT NULL DEFAULT 0,
        h13 integer NOT NULL DEFAULT 0,
        h14 integer NOT NULL DEFAULT 0,
        h15 integer NOT NULL DEFAULT 0,
        h16 integer NOT NULL DEFAULT 0,
        h17 integer NOT NULL DEFAULT 0,
        h18 integer NOT NULL DEFAULT 0,
        h19 integer NOT NULL DEFAULT 0,
        h20 integer NOT NULL DEFAULT 0,
        h21 integer NOT NULL DEFAULT 0,
        h22 integer NOT NULL DEFAULT 0,
        h23 integer NOT NULL DEFAULT 0
      )
    ')

    silentSql ('
      CREATE TABLE IF NOT EXISTS stats_user_hour (
        user_id integer NOT NULL,
        h0 integer NOT NULL DEFAULT 0,
        h1 integer NOT NULL DEFAULT 0,
        h2 integer NOT NULL DEFAULT 0,
        h3 integer NOT NULL DEFAULT 0,
        h4 integer NOT NULL DEFAULT 0,
        h5 integer NOT NULL DEFAULT 0,
        h6 integer NOT NULL DEFAULT 0,
        h7 integer NOT NULL DEFAULT 0,
        h8 integer NOT NULL DEFAULT 0,
        h9 integer NOT NULL DEFAULT 0,
        h10 integer NOT NULL DEFAULT 0,
        h11 integer NOT NULL DEFAULT 0,
        h12 integer NOT NULL DEFAULT 0,
        h13 integer NOT NULL DEFAULT 0,
        h14 integer NOT NULL DEFAULT 0,
        h15 integer NOT NULL DEFAULT 0,
        h16 integer NOT NULL DEFAULT 0,
        h17 integer NOT NULL DEFAULT 0,
        h18 integer NOT NULL DEFAULT 0,
        h19 integer NOT NULL DEFAULT 0,
        h20 integer NOT NULL DEFAULT 0,
        h21 integer NOT NULL DEFAULT 0,
        h22 integer NOT NULL DEFAULT 0,
        h23 integer NOT NULL DEFAULT 0
      )
  ')
  end
end