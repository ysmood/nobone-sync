{ kit } = require 'nobone'
kit.require 'colors'

cmder = require 'commander'

cmder.option '-h, --help', 'Help', -> cmder.help()
cmder.option '-s, --server'
cmder.option '-u, --upload <local_file host[:port]/path/to/dir>', 'Upload file or directory to remote host.'

cmder.parse process.argv
if cmder.upload
	if cmder.args.length is 1
		conf = {}

		file = cmder.upload
		file and conf.local_dir = file

		remote = /([^\/:]+)(:\d+)?\/(.*)/.exec cmder.args[0]

		if not remote or not remote[3]
			kit.err 'Wrong argument, host[:port]/path/to/file wanted.'
			process.exit 1

		conf.host = remote[1] or ''
		port = remote[2] or ':8345'
		conf.port = port[1...]
		conf.remote_dir = "/" + remote[3]

		require('./client') conf, false
	else if cmder.args.length isnt 0
		kit.err "Wrong args number, 2 wanted"
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
