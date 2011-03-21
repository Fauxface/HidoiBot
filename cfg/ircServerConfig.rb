# Config file for server details
# Only one server per bot is supported
#
# serverGroup: Just a name used to identify the IRC network you are connecting to
# hostname: Address of the IRC server
# port: Port you are connecting to
# ssl: true for SSL use, false for no SSL use
# nickname: Nickname
# nickserv: If using NickServ on supported IRC servers
# nickservpw: NickServ password if using NickServ
# defaultChannels: Array of channels, in the format ['#channel1', '#channel2']

@serverDetails = {
        "serverGroup" => 'Rizon',
        "hostname" => 'irc.rizon.net',
        "port" => '6666',
        "ssl" => false,
        "nickname" => 'HidoiBot2000',
        "nickserv" => '',
        "nickservpw" => '',
        "defaultChannels" => ['#HidoiBot']
}

# You can name any inactive server config as follows:
# As long as the name isn't serverDetails it will not be loaded
inactiveServerDetails2 = {
        "serverGroup" => 'Rizon',
        "hostname" => 'irc.rizon.net',
        "port" => '6697',
        "ssl" => true,
        "nickname" => 'HidoiBot2',
        "nickserv" => '',
        "nickservpw" => '',
        "defaultChannels" => ['#HidoiBot', '#HidoiBot2']
}