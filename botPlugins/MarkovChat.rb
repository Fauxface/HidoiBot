# Ng Guoyou
# MarkovChat.rb
# Attempts to implement a markov-chain-based chat algorithm. Handles learning and chatting.
# A most horrible chat plugin
# First rewrite

class MarkovChat < BotPlugin
  def initialize
    require 'json'
    require 'open-uri'
    require 'iconv'

    # Default Persistent Settings
    @s = {
    # Learn from chat?
    'learning' => true,

    # Add to conversations?
    'chipIn' => true,
    'chipInP' => 0.01,

    # Maximum sentence length. The bot will cut generation off once it hits this length
    'maxWords' => 15,

    # Saves brain every n learns
    'learnBufferThreshold' => 20
    }

    # Other Settings
    # Upcase responses
    @capitalise = false

    # Markov chain length
    @chainLength = 2

    # Paths
    @markovSettingsPath = "botPlugins/settings/markovChat"
    @trainingFile = "braintrain.txt"
    @brainFile = "brain.json"
    @settingsFile = "markovChat/chatSettings.json"

    # Initialization stuff
    @brain = Hash.new
    @wordCount = 0
    @learnBufferCount = 0
    loadBrain
    loadSettings

    # Authorisations
    @reqLearningAuth = 3
    @reqLearningStatusAuth = 0
    @reqChatAuth = 0
    @reqChipAuth = 3
    @reqTrainingStatusAuth = 3
    @reqHaikuAuth = 0

    # Strings
    @learnOnMsg = "Learning is now on."
    @learnOffMsg = "Learning is now off."
    @chipOnMsg = "Chipping in is now on."
    @chipOffMsg = "Chipping in is now off."
    @chipInPMsg = "Probability of chipping in: "
    @noRespMsg = "Derp."
    @noModeMsg = "Invalid mode."

    # Triggers
    @chatTrigger = 'chat'
    @haikuTrigger = 'haiku'

    # Required plugin stuff
    name = self.class.name
    @hook = [@chatTrigger, @haikuTrigger]
    processEvery = @s['learning']
    help = "Usage: #{@haikuTrigger} or #{@chatTrigger} (about <word(s)>|on|off|chipon|chipoff|chipprob <p>|status|haiku)\nFunction: Uses a simple Markov chain implementation to simulate sentience. Use about <word(s)> to chat."
    super(name, @hook, processEvery, help)
  end

  def main(m)
    if m.processEvery && @hook.include?(m.trigger)
      # Not learning triggers
      return nil

    elsif !m.processEvery && @hook.include?(m.trigger)
      # If called using trigger
      # If called using haiku, set mode to haiku
      if !m.processEvery && m.trigger == @haikuTrigger
        mode = 'haiku'
      elsif !m.processEvery && m.mode == 'haiku'
        mode = m.mode
        m.message = m.stripTrigger
      else
        mode = m.mode
      end

      # Modes
      case mode
      when 'learnon'
        if m.authR(@reqLearningAuth)
          @s['learning'] = true
          saveSettings
          m.reply(@learnOnMsg)
        end

      when 'learnoff'
        if m.authR(@reqLearningAuth)
          @s['learning'] = false
          saveSettings
          m.reply(@learnOffMsg)
        end

      when 'chipon'
        if m.authR(@reqChipAuth)
          @s['chipIn'] = true
          saveSettings
          m.reply(@chipOnMsg)
        end

      when 'chipoff'
        if m.authR(@reqChipAuth)
          @s['chipIn'] = false
          saveSettings
          m.reply( @chipOffMsg)
        end

      when 'chipprob'
        if m.authR(@reqChipAuth)
          @s['chipInP'] = m.args[1].to_f
          saveSettings
          m.reply("#{@chipInPMsg}#{@s['chipInP']}")
        end

      when 'status'
        if m.authR(@reqLearningStatusAuth)
          m.reply("Learning: #{@s['learning']}, Chipping In: #{@s['chipIn']} at p #{@s['chipInP'].to_s}\nBrain size: #{@brain.size}")
        end

      when 'train'
        if m.authR(@reqTrainingStatusAuth)
          m.reply(trainBrainWithFile)
          saveBrain
        end

      when 'about'
        if m.authR(@reqChatAuth)
          rs = makeSentence(m)
          m.reply((rs.length > @wordCount) ? rs : @noRespMsg)
        end

      when 'haiku'
        if m.authR(@reqHaikuAuth)
          rs = makeHaiku(m)
          m.reply((rs.length > @wordCount) ? rs : @noRespMsg)
        end

      else
        m.reply(@noModeMsg)
      end

      return nil

    elsif @s['learning'] && m.processEvery
      # Else check if we are learning
      learnLine(m.message)
      @learnBufferCount += 1

      if @learnBufferCount > @s['learnBufferThreshold']
        # Save every n learns
        saveBrain
        @learnBufferCount = 0
      end
    end

    if @s['chipIn']
      rs = randChipIn(m)
      m.reply(rs) if rs != nil
    end

    return nil
  rescue => e
    handleError(e)
    return nil
  end

  def loadBrain
    # Loads the brain.
    # Brain file to load is a class variable.

    File.open("#{@markovSettingsPath}/#{@brainFile}", 'a+') { |file|
      b = JSON.parse(file.read)

      if b.class == Hash
        @brain = b
      else
        raise "Invalid brain: #{@markovSettingsPath}/#{@brainFile}. Loading failed."
      end
    }

    puts "MarkovChat: Brain loaded. Links: Forward brain - #{@brain.size}"
  rescue => e
    handleError(e)
  end

  def saveBrain
    # Saves the brain.
    # Brain file to save is a class variable.

    File.open("#{@markovSettingsPath}/#{@brainFile}", "w") { |file|
      file.puts @brain.to_json
    }
  rescue => e
    handleError(e)
  end

  def trainBrainWithFile(file = @trainingFile, mode = 's')
    # Trains the chatbot using a file.
    #
    # Modes:
    # *+p+ - treat paragraph as a learning sentence
    # *+default+ - treat sentence as a learning sentence

    trainingText = open("#{@markovSettingsPath}/#{file}", 'r').readlines
    oldBrainSize = @brain.size

    trainingText.each { |paragraph|
      paragraph = sanitize(paragraph)

      if mode == p
        learnLine(paragraph)
      else
        paragraph.split('. ').each { |line|
          learnLine(line)
        }
      end
    }

    return "MarkovChat: Brain trained using #{@trainingFile}. Brain size: #{@brain.size}. Added links: #{@brain.size - oldBrainSize}."
  rescue => e
    handleError(e)
    return "MarkovChat: A few errors in reading the training file. If they are UTF-8 errors the brain should have been trained fine using #{@trainingFile}."
  end

  def learnLine(line)
    # Helper method for training and learning
    #
    # Params
    # +line+:: +String+ to clean and add into the brain

    line = sanitize(line)
    addChain(line.split(/ /))
  rescue => e
    handleError(e)
  end

  def addChain(words)
    # Formats words, an array, into a format suitable for pushBrain
    #
    # Params:
    # +words+:: +Array+ of words to be converted into chains and added into the brain

    for i in 0..words.size - @chainLength
      if words.size - i < @chainLength
        # If remaining words are shorter than the chain length
        chain = words[i..words.size]
      else
        chain = words[i..i + @chainLength].join(' ')
      end

      pushBrain(chain, words[i+@chainLength])
    end
  end

  def pushBrain(chain, nextWord)
    # Adds markov chains into the chat brain
    #
    # If the chain already exists, we increment the count
    # The count is used for probalistic determination during sentence generation
    # Else, we insert it into the brain
    #
    # Params:
    # +chain+:: +String+, the chain to add
    # +nextWord+:: +String+, the linking word (ie. the next word directly after the chain)

    key = chain.split(' ').first

    if @brain[key] != nil
      # If word exists
      if @brain[key][chain] != nil && @brain[key][chain][nextWord] != nil
          # If both word and next word exist
          @brain[key][chain][nextWord] += 1
      else
          # Else we create the link
          @brain[key][chain] = Hash.new
          @brain[key][chain][nextWord] = 1
      end
    else
      # New word, new chain
      @brain[key] = Hash.new
      @brain[key][chain] = Hash.new
      @brain[key][chain][nextWord] = 1
    end
  end

  def sanitize(s=words)
    # Handle invalid encoding using information from
    # http://po-ru.com/diary/fixing-invalid-utf-8-in-ruby-revisited/
    #
    # Params:
    # +s+:: +String+ to sanitise.

    ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')
    s = ic.iconv(s << ' ')[0..-2]

    # Special, non-punctuation characters with leading space
    #words.gsub!(/ (\[|\\|\^||\||\?|\*|\+|\(|\)|\]|\/|!|@|#|$|%|&|_|-|=|'|"|:|;|>|?|<|,) ?/, '')

    # URLs
    s = s.gsub(/(http(s?)\:)([\/|.|\w|\s|\:|~]|-)*\..*/i, '')

    # Whitespace
    s = s.gsub(/ +/, '')
    s = s.gsub(/(\t|\n|\r)/, '')
    s = s.lstrip
    s = s.rstrip

    # Downcase
    s = s.downcase

    return s
  end

  def cleanOutput(sentence)
    # Formats output. Converts i's to I's, removes excess whitespace and handles capitalisation
    #
    # Params:
    # +sentence+:: +String+ to clean and format.

    parsedSentence = sentence.gsub(/("|'| )i( |,|-)/, ' I ') # i -> I
    parsedSentence = parsedSentence.gsub('"', '')
    parsedSentence = parsedSentence.lstrip.rstrip # Trailing/Leading whitespace

    if @capitalise
      parsedSentence = parsedSentence.upcase # Capitalises everything
    else
      parsedSentence[0] = parsedSentence[0].upcase # Capitalises only the first letter
    end

    return parsedSentence
  end

  def makeSentence(m)
    # Generates sentences. Probability is not factored in yet -- it treats every chain equally right now.
    # Could use some more refactoring.
    #
    # Params:
    # +m+:: +Message+ from +IRC+

    terminate = false
    sentence = Array.new
    seeds = Array.new
    seedSentence = m.shiftWords(2)

    if seedSentence.size > 0
      # Get a valid seed word if provided with a seed sentence
      seedSentence.split(' ').each { |word|
        seeds.push(word)
      }

      seed = seeds.each { |seed|
        next seed if @brain[seed] != nil
      }[0]
    else
      # Random seed if not given any
      seed = @brain.keys.sample
    end

    # Start sentence off with the seed, since we're going to drop the first words later
    sentence.push(seed)

    while !terminate && @brain[seed] != nil
      # Probablity goes here, replace sample
      word = (@brain[seed].keys).sample

      if word == nil || sentence.size > @s['maxWords']
        terminate = true
      else
        seed = word.split(' ').last # New seed

        if word.split(' ').size > 1
          word = word.split(' ').drop(1).join(' ') # Remove first word
        end

        sentence.push(word)
      end
    end

    return cleanOutput(sentence.join(' '))
  end

  def makeHaiku(m)
    # 5-7-5
    # HidoiBot's haiku
    # Terrible and horrible
    # This is a todo.
    #
    # Seriously, this is bad.
    #
    # Params:
    # +m+:: A +Message+ object.

    terminate = false
    sentence = Array.new
    seeds = Array.new
    lineSyllableCount = 0
    line = 0
    tries = 0
    seedSentence = m.shiftWords(1)

    if seedSentence.size > 0
      # Get a valid seed word if provided with a seed sentence
      seedSentence.split(' ').each { |word|
        seeds.push(word)
      }

      seed = seeds.each { |seed|
        next seed if @brain[seed] != nil && countSyllables(seed) <= 5
      }[0]

      seed = @brain.keys.sample if seed == nil || countSyllables(seed) > 5
    else
      # Random seed if not given any
      seed = @brain.keys.sample
    end

    # Start sentence off with the seed, since we're going to drop the first words later
    sentence.push(seed)
    lineSyllableCount += countSyllables(seed)

    timeout(15) do
      # Protection against infinite loops due to bad code
      while !terminate
        # So we don't alter the actual brain
        curSeedOptions = @brain[seed].clone if @brain[seed] != nil
        newSeed = false

        while !newSeed && !terminate
          # Get next chain
          if curSeedOptions == nil
            # Exhausted our current options, get a new seed and its options
            newSeed = true
            oldSeed = seed

            # Try to get a new seed from its current options
            seed = seeds.each { |seed|
              next seed if @brain[seed] != nil && countSyllables(seed) <= 5 && seed != oldSeed
            }[0]

            seed = @brain.keys.sample if seed == oldSeed # New random seed if we cannot find an alternative
          else
            # Else, get a random word
            word = curSeedOptions.keys.sample

            if !newSeed && line <= 2 && word != nil
              # Remove first word
              originalWord = word
              word = word.split(' ').drop(1).join(' ')
              syllables = countSyllablesInSentence(word)

              # Add it to our haiku
              if (syllables + lineSyllableCount <= 5 && line != 1) ||
                 (syllables + lineSyllableCount <= 7 && line == 1)
                # If valid addition
                seed = word.split(' ').last # New seed
                newSeed = true
                sentence.push(word)
                lineSyllableCount += syllables
              else
                curSeedOptions.delete(originalWord)
                curSeedOptions = nil if curSeedOptions.size == 0
              end
            end
          end

          # Check for structure
          if (lineSyllableCount == 6 - @chainLength && line != 1) ||
             (lineSyllableCount == 8 - @chainLength && line == 1)
            # We do this because monosyllabic words are impossible in a word chain of length two
            # !-Cheap trick-!

            tries = 0
            maxTries = 15

            begin
              seed = @brain.keys.sample # Pick random new seed
              tries += 1
            end while countSyllables(seed) != 1 && tries <= maxTries

            seed = ["and", "so", "then", "but"].sort_by{ rand }.first if tries > maxTries # Pick random filler if failed
            newSeed = true
            sentence.push(seed).push("\n")
            lineSyllableCount = 0
            line += 1
          elsif (lineSyllableCount == 5 && line != 1) ||
                (lineSyllableCount == 7 && line == 1)
            # Line has hit its quota
            sentence.push("\n")
            lineSyllableCount = 0
            line += 1
          elsif sentence.size > 19 || line > 2
            # 5 + 7 + 5 + 2x '\n' == 19
            # Line count starts from 0
            terminate = true
          end
        end
      end
    end

    return cleanOutput(sentence.join(' ').gsub(" \n ", "\n").gsub(/  +/,' '))
  rescue => e
      handleError(e)
      puts "MarkovChat: Haiku derped out -- seed: #{seed}, brain[seed]: #{@brain[seed]}"
      return @noRespMsg
  end

  def countSyllables(text)
    # Counts and returns the number of syllables in text, a word
    # Taken from http://stackoverflow.com/questions/1271918/ruby-count-syllables
    #
    # Params:
    # +text+:: A word.

    word = text.downcase
    return 1 if word.length <= 3
    word.sub!(/(?:[^laeiouy]es|ed|[^laeiouy]e)$/, '')
    word.sub!(/^y/, '')
    return word.scan(/[aeiouy]{1,2}/).size
  end

  def countSyllablesInSentence(text)
    # Counts and returns the number of syllables in text, a sentence
    # Adapted from http://stackoverflow.com/questions/1271918/ruby-count-syllables
    #
    # Params:
    # +text+:: A sentence.

    sentence = text
    sentence.gsub!(/\W+/, ' ') # Strip punctuation
    words = sentence.split(' ')
    count = 0

    words.each { |word|
      count += countSyllables(word)
    }

    return count
  end

  def randChipIn(m)
    # Handles quipping.
    #
    # Params:
    # +m+:: For passing to +makeSentence+ if needed.

    if rand < @s['chipInP']
      wittyAttempt = makeSentence(m)

      # If we have something constructive to add
      m.reply(wittyAttempt) if wittyAttempt.length > 1 && wittyAttempt.upcase != m.message.upcase
    end

    return nil
  end
end