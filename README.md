HidoiBot
========

Intro
-----
HidoiBot is an awful IRC bot written in Ruby.

HidoiBot v1 was created in the second half of 2010 with the intent of learning Ruby. It was also written badly.
HidoiBot v2 is a near-complete rewrite of HidoiBot v1, done in early 2011, with slightly better writing.

There are several notable inadequacies in v2 -- I had to 'hack' in solutions and implement 'half-past-six' code or HidoiBot v2 would never have been completed. Essentially, corners were cut. So many, that it's beginning to look like a circle.

Additional major refactoring work was done in December 2011.

Installation
------------
HidoiBot is tested on Ubuntu 10.04, with Ruby 1.9.2 installed. Older versions of Ruby might work, but are untested. It might work on Windows, and there shouldn't be any huge issues with that.

Pull the source and install the following stuff:

### Absolutely required:

* Ruby - tested on version 1.9.2
* `rubygems` - this should come with a Ruby install
* `json` or `json/pure` - `gem install json` or `gem install json_pure`

### Pretty much required:

* `nokogiri` - `gem install nokogiri`
    
### Might be required:
* `sqlite3` - `gem install sqlite3` <br>
If you're getting an error try these

### Stuff you might want:

* A proper webserver on the bot's computer, such as Apache2 or lighttpd
* Access to Media Player Classic (MPC) with Web UI turned on for MPC sync/now playing capabilities
* An Internet connection
        
Quick Start
-----------
1. Install the REQUIRED STUFF
2. Modify the config files in directory `cfg`
3. Run HidoiBot2.rb
5. Configure default plugins as needed
    
Configuring Default Plugins
---------------------------
1. MpcSync - Check if MPC's address, port and the port on which you are listening for 'GO!' packets are correct.
2. WolframAlpha - Insert your own W|A API key here. W|A imposes a monthly limit on API calls.
3. RottenTomatoes - Same deal here. Insert your own API key if you so desire.
4. ImageScraper - If you wish to change the directory scraped images are saved in, change it here.
5. MarkovChat - "settings/markovChat/braintrain.txt" is the training file for Markov chat. Use ~chat train to train HidoiBot.

Additionally, required authorisation levels can be changed for all bot functions in their respective BotPlugin files.

Usage
-----
### To access commands:

> `<trigger><hook>`
>
>    If the trigger is `~` and the hook is `ping` enter `~ping` in a channel which HidoiBot is in. <br>
>    Default trigger: `~`
    
### To access command list:
> `help`
    
### Individual plugin help:
> `help <plugin hook>`
    
### To authenticate:
> `auth <password>`
>
> Passwords and authorisation levels are found in `cfg/authConfig.rb` <br>
> Default passwords: password1, password2, password3
    
### Bot console:
> If you need to do this for whatever reason, enter `/<$botName.method>` into the console. This will be evaluated by the bot.
>
> `/$bot1.sayTo('#hidoi', 'Hi')` <br>
> `/$bot1.reconnect`
    
If you are using a web server: make the root directory 'public'

Plugins
-------
### Creating plugins:
HidoiBot has a plugin system which can be used to include additional functionality.

> See `botPlugins/Ping.rb` for details. <br>
> See `botPlugins/inactive/Template.rb` for a plugin template.
Commonly used methods and accessors will be in `core/BotPlugin.rb` and `core/Message.rb`.

### Notable default plugins:

* HidoiIMS: ImageScraper, ImageTagger, ImageSearch
* Media Player Classic syncronisation and now playing information
* User and channel statistics and user last seen information
* Hiragana and Katakana to Romanji transliterator
* MarkovChat, a rudimentary chat plugin

### To turn plugins off:

* The plugin might have an internal 'off' switch, check help <plugin>
* Move the plugin into the inactive directory, and do a reload

This is currently horribly written.

### To add plugins: 
For most plugins, dump the `plugin.rb` file in `botPlugins` and it'll work fine. Rename `plugin.rb` to whatever the plugin class name is.
    
### To change plugin authorisation level:
Open the file with the plugin you wish to modify the required authorisation level for and search for the authorisation variables. They should be in the `initialize` method of the plugins. Failing that, try a search for `.auth` or `.authR`.

This is also horribly written.