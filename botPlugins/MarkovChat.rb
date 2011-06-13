# A most horrible chat plugin
class MarkovChat < BotPlugin
    def initialize
        require 'json'
        #require 'json/pure'
        require 'open-uri'
        
        # Default Persistent Settings
        @s = {
        # Learn from chat?
        'learning' => true,
        
        # Add to conversations?
        'chipIn' => true,
        'chipInP' => 0.01,
        
        # Per side, multiply by two for total. Set to a high number for more natural-looking, long-winded, formations.
        'maxWords' => 15,
        
        # Saves brain every n learns
        'learnBufferThreshold' => 20
        }
        
        # Other Settings
        # Shortens sentences by terminating chains when a link's strength is too weak.
        # This should improve with increasing brain size; set to a small number if your bot is dim-witted
        @gibberishTerminator = 0.005
        
        # Markov chain length
        @chainLength = 2
        
        # Paths
        #@configPath = "botPlugins/settings/markovChat"
        @markovSettingsPath = "botPlugins/settings/markovChat" # for brain
        @trainingFile = "braintrain.txt"
        @brainFile = "brain.rb"
        @brainRevFile = "brainRev.rb"
        #@settingsFile = "chatSettings.txt"
        @settingsFile = "markovChat/chatSettings.txt"
        
        # Initialization stuff
        @brain = Hash.new
        @brainRev = Hash.new
        @wordCount = 0
        @learnBufferCount = 0
        #trainBrainWithFile
        loadBrain
        loadSettings
        
        # Authorisations
        @reqLearningAuth = 3
        @reqLearningStatusAuth = 0
        @reqChatAuth = 0
        @reqChipAuth = 3
        @reqTrainingStatusAuth = 3
        
        # Strings
        @learnOnMsg = "Learning is now on."
        @learnOffMsg = "Learning is now off."
        @chipOnMsg = "Chipping in is now on."
        @chipOffMsg = "Chipping in is now off."
        @chipInPMsg = "Probability of chipping in: "
        @noRespMsg = "Derp."
        
        # Required plugin stuff
        name = self.class.name
        @hook = 'chat'
        processEvery = @s['learning']
        help = "Usage: #{@hook} (about <word(s)>|on|off|chipon|chipoff|chipprob <p>|status)\nFunction: Uses a simple Markov chain implementation to simulate sentience. Use about <word(s)> to chat."
        super(name, @hook, processEvery, help)
    end
    
    def main(data)
        @givenLevel = data["authLevel"]
        
        if data["processEvery"] == true && data["trigger"] == @hook
            # Not learning triggers
            return nil
        
        elsif data["processEvery"] != true && data["trigger"] == @hook
            # If called using trigger
            mode = detectMode(data)
            
            # Modes
            if mode == 'learnon' && checkAuth(@reqLearningAuth)
                @s['learning'] = true
                saveSettings
                return sayf(@learnOnMsg)
            
            elsif mode == 'learnoff' && checkAuth(@reqLearningAuth)
                @s['learning'] = false
                saveSettings
                return sayf(@learnOffMsg)
                
            elsif mode == 'chipon' && checkAuth(@reqChipAuth)
                @s['chipIn'] = true
                saveSettings
                return sayf(@chipOnMsg)
                
            elsif mode == 'chipoff' && checkAuth(@reqChipAuth)
                @s['chipIn'] = false
                saveSettings
                return sayf(@chipOffMsg)
            
            elsif mode == 'chipprob'  && checkAuth(@reqChipAuth)
                @s['chipInP'] = arguments(data)[1].to_f
                saveSettings
                return sayf("#{@chipInPMsg}#{@s['chipInP']}")
                
            elsif mode == 'status' && checkAuth(@reqLearningStatusAuth)
                rs = "Learning: #{@s['learning']}, Chipping In: #{@s['chipIn']} at p #{@s['chipInP'].to_s}\nBrain size: Forward - #{@brain.size}, Reverse - #{@brainRev.size}"
                return sayf(rs)
                
            elsif mode == 'train' && checkAuth(@reqTrainingStatusAuth)
                rs = trainBrainWithFile
                saveBrain
                return sayf(rs)
                
            elsif mode == 'about' && checkAuth(@reqChatAuth)
                rs = chatTopic(data)
                
                if rs.length > 0
                    return sayf(rs)
                else
                    return sayf(@noRespMsg)
                end
            end
            
        elsif @s['learning'] == true && data['processEvery'] == true
            # Else check if we are learning
            learnLine(data["message"])
            @learnBufferCount += 1
            
            if @learnBufferCount > @s['learnBufferThreshold']
                # Save every n learns
                saveBrain
                @learnBufferCount = 0
            end
        end
        
        if @s['chipIn'] == true
            rs = randChipIn(data)
            return sayf(rs) if rs != nil
        end
        
    rescue => e
        handleError(e)
        return nil
    end
    
    def loadBrain
        b = JSON.parse(open("#{@markovSettingsPath}/#{@brainFile}", 'a+').read)
        br = JSON.parse(open("#{@markovSettingsPath}/#{@brainRevFile}", 'a+').read)
        
        if b.class == Hash
            @brain = b
        end
        
        if br.class == Hash
            @brainRev = br
        end
        
        puts "MarkovChat: Brain loaded. Links: Forward brain - #{@brain.size}, Reverse brain - #{@brainRev.size}."
    rescue => e
        handleError(e)
    end
    
    def saveBrain
        f = File.open("#{@markovSettingsPath}/#{@brainFile}", "w")
        f.puts @brain.to_json
        f.close
        
        g = File.open("#{@markovSettingsPath}/#{@brainRevFile}", "w")
        g.puts @brainRev.to_json
        g.close
    rescue => e
        handleError(e)
    end

    def trainBrainWithFile(file = @trainingFile)
        trainingText = open("#{@configPath}/#{file}", 'r').readlines
        
        trainingText.each { |paragraph|
            # learnLine(paragraph) for longer text - this will create a larger brain file, but will be able to link sentences
            # learnLine(line) will only do sentences for a smaller file
            # Switch out the two blocks for different purposes
            paragraph = sanitize(paragraph)
            
            #learnLine(paragraph)
            paragraph.split('. ').each{ |line|
                learnLine(line)
            }
        }
        
        return "MarkovChat: Brain trained using #{@trainingFile}."
    rescue => e
        handleError(e)
        return "MarkovChat: A few errors in reading the training file. If they are UTF-8 errors the brain should have been trained fine using #{@trainingFile}."
    end
    
    def learnLine(line)
        line = sanitize(line)
        addChain(line.split(/ /))
    rescue => e
        handleError(e)
    end
    
    def addChain(words)
        chainLength = @chainLength - 1
        terminatingIndex = words.size - @chainLength
        
        for i in 0..words.size - (@chainLength)
            if i < terminatingIndex
                pushBrain(words[i..(i+chainLength)].join(' '), words[i + chainLength + 1])
                words.reverse!
                pushBrainRev(words[i..(i+chainLength)].join(' '), words[i + chainLength + 1])
                words.reverse!
            else
                pushBrain(words[i..(i+chainLength)].join(' '), nil)
                words.reverse!
                pushBrainRev(words[i + chainLength], nil)
                words.reverse!
            end
        end
    end
    
    def sanitize(s=words)
        # Handle invalid encoding
        # http://po-ru.com/diary/fixing-invalid-utf-8-in-ruby-revisited/
        ic = Iconv.new('UTF-8//IGNORE', 'UTF-8')        
        s = ic.iconv(s << ' ')[0..-2]
        
        # Special, non-punctuation characters with leading space
        #words.gsub!(/ (\[|\\|\^||\||\?|\*|\+|\(|\)|\]|\/|!|@|#|$|%|&|_|-|=|'|"|:|;|>|?|<|,) ?/, '')
        
        # URLs
        s = s.gsub(/(http(s?)\:)([\/|.|\w|\s|\:|~]|-)*\..*/i, '')
        
        # Whitespace
        s = s.gsub(/(  +|^ | $|\t|\n|\r)/, ' ')
        s = s.lstrip
        s = s.rstrip
        
        # Downcase
        s = s.downcase
        
        return s
    end
    
    def cleanOutput(sentence)
        parsedSentence = sentence.gsub(/("|'| )i( |,|-)/, ' I ') # i -> I
        parsedSentence = parsedSentence.lstrip.rstrip # Trailing/Leading whitespace
        #parsedSentence = parsedSentence.upcase # Capitalises everything
        parsedSentence[0] = parsedSentence[0].upcase # Capitalises only the first letter
        
        return parsedSentence
    end
    
    # !-BAD CODE ZONE-!
    def pushBrain(word1, word2)
        wordStart = word1.split(' ')[0]
        
        # If the chain already exists, we increment the count
        # Else, we insert it into the brain
        if @brain[word1] != nil
            if @brain[word1][word2] != nil
                @brain[word1][word2] = @brain[word1][word2] + 1
            else
                @brain[word1][word2] = 1
            end
        else
            @brain[word1] = Hash.new
            @brain[word1][word2] = 1
        end
        
        # Chains indexed by first word - done so we can link chains together
        if @brain[wordStart] != nil
            if @brain[wordStart][word1] != nil
                @brain[wordStart][word1] = @brain[wordStart][word1] + 1
            else
                @brain[wordStart][word1]
            end
        else
            @brain[wordStart] = Hash.new
            @brain[wordStart][word1] = 1
        end
    end
    
    # Fix: code reuse
    def pushBrainRev(word1, word2)
        wordStart = word1.split(' ')[0]
        
        if @brainRev[word1] != nil
            if @brainRev[word1][word2] != nil
                @brainRev[word1][word2] = @brainRev[word1][word2] + 1
            else
                @brainRev[word1][word2] = 1
            end
        else
            @brainRev[word1] = Hash.new
            @brainRev[word1][word2] = 1
        end
        
        if @brainRev[wordStart] != nil
            if @brainRev[wordStart][word1] != nil
                @brainRev[wordStart][word1] = @brainRev[wordStart][word1] + 1
            else
                @brainRev[wordStart][word1]
            end
        else
            @brainRev[wordStart] = Hash.new
            @brainRev[wordStart][word1] = 1
        end
    end
    
    def getProbWord(word, direction)        
        keys = Array.new
        counts = Array.new
        
        if direction == 'forward'
            if @brain[word] != nil
                @brain[word].each{ |pword|
                    keys.push (pword[0]) # Adds available keys (linking chains ie. pword[0]) to array 'keys'
                    counts.push (pword[1]) # Add respective frequencies (ie. pword[1]) to array 'counts'
                }
            else
                # End of chain
                return nil
            end
        
        elsif direction == 'reverse'
            word = word.split(' ').reverse.join(' ')
            
            if @brainRev[word] != nil
                @brainRev[word].each{ |pword|
                    keys.push (pword[0])
                    counts.push (pword[1])
                }
            else
                return nil
            end
        end
        
        # Randomise word selection after options are weighed
        probs = counts.map { |x|
                rand(Math.log(x)) + rand(@gibberishTerminator * 3)
                
                # Various other tries
                #x * Math.log(keys.length()) + rand(x)
                #rand(x) * Math.log(keys.length())
                #x * rand()
            }
        
        #puts "WORD: #{word}, DIRECTION: #{direction} --- KEYS: #{keys} PROBS: #{probs.inspect} COUNTS: #{counts.inspect}"
        chosenIndex = probs.each_with_index.max[1]
        
        if probs[chosenIndex] > @gibberishTerminator
            keyOfChoice = keys[chosenIndex]
            
            if direction == 'reverse' && keyOfChoice != nil
                # The key is stored in reverse in the reverse brain
                keyOfChoice = keyOfChoice.split(' ').reverse.join(' ')
            end
            
            return keyOfChoice
        else
            return nil
        end
    rescue => e
        handleError(e)
    end
    
    def chatTopic(data)
        seeds = Array.new
        seedSentence = stripWordsFromStart(data["message"], 2)
        seeds.push(seedSentence.split(' '))
        
        #if seeds[0].size == @chainLength
            # If we have a phrase that can potentially be a chain itself
        
        if seeds[0].size > 1
            # If input is a phrase
            seeds = seeds[0]
            seedRev = "#{seeds.first}"
            seedFor = "#{seeds.last}"
            
            return makeSentence(seedRev, seedFor, seedSentence)
        elsif seeds.size == 1
            # If input is a word
            return makeSentence(seeds[0][0], seeds[0][0], seeds[0][0])
        end
    end
    
    def makeSentence(seedRev, seedFor, seeds='')
        if seeds.class == Array
            seeds = seeds.join(' ')
        end
        
        reverseString = makeChain(seedRev.downcase, 'reverse') 
        forwardString = makeChain(seedFor.downcase)
        rawSentence = stripWordsFromEnd(reverseString, 1) + " #{seeds} " + stripWordsFromStart(forwardString, 1)
        
        return cleanOutput(rawSentence)
    end
    
    def makeChain(seed, direction='forward')
        # Basically this:
        #   1. chain1           -> chain2    # p = rand(count) = 1, picked
        #   2. lastWordOfChain2 -> chain3    # p = 3, picked
        #                       -> chain4    # p = 2
        #                       -> nil       # p = 2, nil terminates chain
        #   3. lastWordOfChain3 -> chain4    # p = 1
        #                       -> chain5    # p = 2, picked
        #                       -> chain6    # p = 0 
        # and so on until either the limit is hit or the chain is terminal
        
        sentence = Array.new
        appendWord = String.new
        
        if @wordCount < @s['maxWords']
            # Check for a link to the previous chain/seed
            appendWord = getProbWord(seed, direction)
            
            if appendWord == nil
                # Add the previous link if it terminates the chain.
                sentence.push(seed)
            elsif appendWord != nil && appendWord.split(' ').size > 1
                # Add the current chain to the sentence if it's not a bridging chain
                sentence.push(appendWord)
            end
            
            if appendWord != nil
                # If there is still a link to another chain
                # Else, we stop the recurrence
                @wordCount += 1
                sentence.push(makeChain(appendWord, direction))
            end
        end
        
        if direction == 'reverse'
            sentence = sentence.reverse
        end
        
        @wordCount = 0

        return sentence.join(' ').rstrip.lstrip
    rescue => e
        handleError(e)
    end
    
    def randChipIn(data)
        if rand < @s['chipInP']
            topic = data["message"].split(' ')
            topic = [topic[rand(topic.size)]]
            wittyAttempt = makeSentence(topic[0], topic[0], topic[0])
            
            if wittyAttempt.length > 1 && wittyAttempt != topic && wittyAttempt != data["message"].upcase
                # If we have something constructive to add
                return wittyAttempt
            else
                return nil
            end
        else
            return nil
        end
    end
end