kit = require 'nokit'
cs = kit.require 'colors/safe'

cmder = require 'commander'

cmder.option '-h, --help', 'Help', -> cmder.help()
cmder.option '-s, --server'
cmder.option '-u, --upload [localFile host[:port]/path/to/dir]', 'Upload file or directory to remote host.'
cmder.option '-p, --password <pwd>', 'Password.'
cmder.option '-a, --algorithm <alg>', 'Algorithm', 'aes128'
cmder.option '-v, --ver', 'Print version', ->
	console.log (require './package.json').version
	process.exit()

cmder.parse process.argv

cliConf = {}
configFile = cmder.args[0] or cmder.args[1]

if cmder.upload
	if cmder.upload == true
		configFile = cmder.args[0]
	else
		cliConf.localDir = cmder.upload

		remote = null
		kit._.find cmder.args, (arg, index) ->
			remote = /([^\/:]+)(:\d+)?\/(.*)/.exec arg
			cmder.args.splice(index, 1) if remote
			remote

		if remote
			if !remote[3]
				kit.err 'Wrong argument, host[:port]/path/to/file wanted.'
				process.exit 1
			cliConf.host = remote[1] or ''
			port = remote[2] or ':8345'
			cliConf.port = port[1...]
			cliConf.remoteDir = "/" + remote[3]

		configFile = cmder.args[0]

cmder.password and cliConf.password = cmder.password
cmder.algorithm and cliConf.algorithm = cmder.algorithm

try
	require 'coffee-script/register'
	conf = require kit.path.resolve(configFile)
catch err
	if cmder.args.length > 0
		kit.err err.stack
		process.exit 1
	else
		kit.log cs.yellow 'No config specified, use default.'
		conf = {}

kit._.extend(conf, cliConf)

if cmder.server
	app = require './server'
else
	app = require './client'

app conf, !cmder.upload

