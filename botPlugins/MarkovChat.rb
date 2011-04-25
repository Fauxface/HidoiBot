# A most horrible chat plugin
class MarkovChat < BotPlugin
    def initialize
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
        'learnBufferThreshold' => 7
        }
        
        # Other Settings
        # Shortens sentences by terminating chains when a link's strength is too weak.
        # This should improve with increasing brain size; set to a small number if your bot is dim-witted
        @gibberishTerminator = 0.01
        
        # Markov chain length
        @chainLength = 2
        
        # Paths
        @configPath = "botPlugins/settings/markovChat"
        @trainingFile = "braintrain.txt"
        @brainFile = "brain.rb"
        @brainRevFile = "brainRev.rb"
        @settingsFile = "chatSettings.txt"
        
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
        help = "Usage: #{@hook} (about <word(s)>|on|off|chipon|chipoff|chipprob <p>|status)\nFunction: Uses a simple Markov chain implementation to simulate sentinence. Use about <word(s)> to chat."
        super(name, @hook, processEvery, help)
    end
    
    def main(data)
        @givenLevel = data["authLevel"]

        if data["trigger"] == 'processEvery' && detectTrigger(data) == @hook
            # Not learning triggers
            return nil
            
        elsif data["trigger"] == @hook 
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
            
        elsif @s['learning'] == true 
            # Else check if we are learning
            learnLine(data["message"])
            @learnBufferCount += 1
            
            if @learnBufferCount > @s['learnBufferThreshold']
                # Save every n learns
                saveBrain
                @learnBufferCount = 0
            end
        end
        
        if @s['chipIn'] == true && rand < @s['chipInP']
            return sayf(randChipIn(data))
        end
        
    rescue => e
        handleError(e)
        return nil
    end
    
    # Hacked-in loading/saving
    def loadBrain
        b = eval(open("#{@configPath}/#{@brainFile}", 'a+').read)
        br = eval(open("#{@configPath}/#{@brainRevFile}", 'a+').read)
        
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
        f = File.open("#{@configPath}/#{@brainFile}", "w")
        f.puts @brain
        f.close
        
        g = File.open("#{@configPath}/#{@brainRevFile}", "w")
        g.puts @brainRev
        g.close
    rescue => e
        handleError(e)
    end
    
    def loadSettings
        p = eval(open("#{@configPath}/#{@settingsFile}", "a+").read)
        
        if p.class == Hash
            @s = p
        end
    rescue => e
        handleError(e)
    end
    
    def saveSettings
        f = File.open("#{@configPath}/#{@settingsFile}", "w")
        f.puts @s
        f.close
    rescue => e
        handleError(e)
    end
    
    def trainBrainWithFile(file = @trainingFile)
        trainingText = open("#{@configPath}/#{file}", 'r').readlines
        
        trainingText.each { |paragraph|
            # learnLine(paragraph) for longer text - this will create a larger brain file, but will be able to link sentences
            # learnLine(line) will only do sentences for a smaller file
            # Switch out the two blocks for different purposes
            
            #learnLine(paragraph)
            paragraph.split('. ').each{ |line|
                learnLine(line)
            }
        }
        
        return "MarkovChat: Brain trained using #{@trainingFile}."
    rescue => e
        handleError(e)
    end
    
    def learnLine(line)
        line = sanitize(line)
        addChain(line.split(/ /))
    rescue => e
        handleError(e)
    end
    
    def addChain(words)
        chainLength = @chainLength - 1
        
        for i in 0..words.size - (@chainLength + 1)
            # -2: -1 because we start from 0 and another -1 because we don't want to make the loop overshoot
            pushBrain(words[i..(i+chainLength)].join(' '), words[i + chainLength + 1])
            
            words.reverse!
            pushBrainRev(words[i..(i+chainLength)].join(' '), words[i + chainLength + 1])
            words.reverse!
        end
    end
    
    def sanitize(words)
        s = words
        
        # Special, non-punctuation characters with leading space
        #words.gsub!(/ (\[|\\|\^||\||\?|\*|\+|\(|\)|\]|\/|!|@|#|$|%|&|_|-|=|'|"|:|;|>|?|<|,) ?/, '')
        
        # URLs
        s = s.gsub(/(http(s?)\:)([\/|.|\w|\s|\:|~]|-)*\.(?:jpg|gif|png|bmp)/i, '')
        
        # Whitespace
        s = s.gsub(/(  +|^ | $|\t|\n|\r)/, ' ')
        s = s.lstrip
        s = s.rstrip
        
        # Downcase
        s = s.downcase
    
        return s
    end
    
    def cleanOutput(sentence)
        # i -> I
        parsedSentence = sentence.gsub(/("|'| )i( |,|-)/, ' I ')
        
        # Trailing/Leading whitespace
        parsedSentence = parsedSentence.lstrip.rstrip
        
        parsedSentence = parsedSentence.upcase
        
        return parsedSentence
    end
    
    # !-BAD CODE ZONE-!
    def pushBrain(word1, word2)
        wordStart = word1.split(' ')[0]
        
        # For chains
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
                    keys.push (pword[0])
                    counts.push (pword[1])
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
        
        # Random premature termination of chain
        #if counts.size == 1
        #    keys.push(nil)
        #    @terminationP = 0.382
        #    counts.push(@terminationP)
        #end
        
        probs = counts.map{ |x|
                # Gibberish reduction attempt
                #Math::sqrt(x) * rand()
                x * rand()
            }
        
        chosenIndex = probs.each_with_index.max[1]
        
        # Another attempt at reducing gibberish, only use stronger word chains?        
        if counts[chosenIndex] * probs[chosenIndex] <= @gibberishTerminator
            return nil
        else
            # You're a winner!
            keyOfChoice = keys[chosenIndex]
            
            if direction == 'reverse'
                # The key is stored in reverse in the reverse brain
                keyOfChoice = keyOfChoice.split(' ').reverse.join(' ')
            end
            
            return keyOfChoice
        end
    rescue => e
        handleError(e)
    end
    
    def chatTopic(data)
        seeds = Array.new
        seedSentence = stripWordsFromStart(data["message"], 2)
        seeds.push(seedSentence.split(' '))
        
        if seeds[0].size > 1
            # If input is a phrase
            seeds = seeds[0]
            seedRev = "#{seeds.first} #{seeds[1]}"
            seedFor = "#{seeds[seeds.size - 2]} #{seeds.last}"
            
            return makeSentence(seedRev, seedFor, seedSentence)
            
        elsif seeds.size == 1
            # If input is a word
            return makeSentence(seeds[0], seeds[0], seeds[0])
        end
    end
    
    def makeSentence(seedRev, seedFor=seedRev, seeds='')
        if seeds.size > 1
            reverseString = makeChain(seedRev, 'reverse') 
            forwardString = makeChain(seedFor)
            rawSentence = reverseString + " #{seeds} " + forwardString
            
        elsif seeds.size == 1
            reverseString = makeChain(seedRev[0], 'reverse') 
            forwardString = makeChain(seedFor[0])
            rawSentence = reverseString + " " + stripWordsFromStart(forwardString, 1)
        end
        
        return cleanOutput(rawSentence)
    end
    
    def makeChain(seed, direction='forward')
        sentence = Array.new
        appendWord = String.new
        
        if @wordCount < @s['maxWords']
            appendWord = getProbWord(seed, direction)
            
            if appendWord != nil
            
                if appendWord.split(' ').size > 1
                    # I HAVE NO IDEA WHY THIS MAKES THE RESULT BETTER
                    parsedAppendWord = stripWordsFromStart(appendWord, 0)
                end
                
                sentence.push(parsedAppendWord)
            end
            
            @wordCount += 1
                
            if appendWord != nil
                sentence.push (makeChain(appendWord, direction))
            end
        end
        
        @wordCount = 0
        
        sentence.delete_if{ |x|
            x == nil
        }
        
        if direction == 'reverse'
            sentence = sentence.reverse
        end
        
        return sentence.join(' ').rstrip.lstrip
    rescue => e
        handleError(e)
    end
    
    def randChipIn(data)
        topic = data["message"].split(' ')
        topic = [topic[rand(topic.size)]]
        
        wittyAttempt = makeSentence(topic, topic, topic)
        
        if wittyAttempt.length > 0 && wittyAttempt != topic
            # If we have something constructive to add
            return wittyAttempt
        end
    end
end