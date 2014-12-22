{ kit } = require 'nobone'

cmder = require 'commander'

cmder.option '-h --help', 'Help', -> cmder.help()
cmder.option '-s --server'

cmder.parse process.argv

try
	conf = require kit.path.resolve(cmder.args[1])
catch err
	kit.err err.toString()
	kit.log 'No config specified, use default config.'.yellow
	conf = {}
kit._.defaults conf, require('./config.default')

if cmder.server
	app = require './server'
else
	app = require './client'

app conf
