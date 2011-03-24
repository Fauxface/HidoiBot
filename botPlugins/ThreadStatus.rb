class ThreadStatus < BotPlugin
    def initialize
        # Required plugin stuff
        name = self.class.name
        hook = 'threads'
        processEvery = false
        help = "Function: Returns running threads."
        super(name, hook, processEvery, help)
    end

    def main(data)
        @givenLevel = data["authLevel"]
        return "say '#{threadInfo}'"
    rescue => e
        handleError(e)
        return nil
    end
    
    def threadInfo()
        requiredAuth = 3
        if authCheck(requiredAuth)
            rs = ''
            Thread.list.map {|x|
                #rs = rs + "#{x.inspect}: #{x[:name]}\n"
                rs = rs + "#{x.inspect}\n"
            }
            return rs
        else
            return nil
        end
	end
end