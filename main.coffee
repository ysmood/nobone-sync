{ kit } = require 'nobone'

cmder = require 'commander'

cmder.option '-h, --help', 'Help', -> cmder.help()
cmder.option '-s, --server'
cmder.option '-u, --upload <local_file remote_url remote_path>'

cmder.parse process.argv

if cmder.upload
	if cmder.args.length is 2
		conf = {}
		file = cmder.upload
		remote_host = cmder.args[0]
		remote_path = cmder.args[1]

		host = remote_host.split ':'
		file and conf.local_dir = file
		conf.host = host[0]
		host[1] and conf.port = host[1]
		remote_path and conf.remote_dir = remote_path

		require('./client') conf, false
	else if cmder.args.length isnt 0
		kit.log "Wrong args number, 3 wanted"
else

	try
		conf = require kit.path.resolve(cmder.args[1])
	catch err
		kit.err err.toString()
		kit.log 'Config error, use default config.'.yellow
		conf = {}
	kit._.defaults conf, require('./config.default')

	if cmder.server
		app = require './server'
	else
		app = require './client'
	app conf
