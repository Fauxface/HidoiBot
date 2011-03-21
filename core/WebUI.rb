# encoding:utf-8
module WebUI
	def startWebrick(config = {})
        require 'webrick'
        require 'cgi'
        include WEBrick
        
        puts 'Starting WEBrick server...'
        
        #@serverPort = 80
		#config.update(:Port => @serverPort)
		#config.update(:MimeTypes => {'jpeg' => 'application/octet-stream'})
		server = HTTPServer.new(config)
		
		yield server if block_given?
			['INT', 'TERM'].each {|signal|
			trap(signal) {server.shutdown}
			}
		
		ruby_dir = File.expand_path('public')
		server.mount("public", HTTPServlet::FileHandler, ruby_dir)		
		server.start
	end
		
	def mkHead(file, title, *extCss)
		f = File.open(file, "w+")
            f.puts("<!DOCTYPE = HTML>")
		if extCss[0] == nil
			f.puts("<html><head><title>#{title}</title></head>")
			f.close
		elsif extCss[0] != nil
			f.puts("<html><head><title>#{title}</title><link rel=\"stylesheet\" type=\"text/css\" href=\"#{extCss[0]}\" /></head><body>")
		end
    rescue => e
        puts e
    ensure
        f.close
	end
		
	def	mkBody(file, code)
		f = File.open(file, "a")
		f.puts("#{code}")
    rescue => e
        puts e
    ensure
        f.close
	end
	
	def mkEnd(file)
		f = File.open(file, "a")
		f.puts("</body></html>")
    rescue => e
        puts e
    ensure
        f.close
	end
end