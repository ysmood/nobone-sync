{ kit } = require 'nobone'

cmder = require 'commander'

cmder.option '-s --server'

cmder.parse process.argv

try
	conf = require kit.path.join(process.cwd(), cmder.args[1])
catch
	kit.log 'No config specified, use default config.'.yellow
	conf = {}
kit._.defaults conf, require('./config.default')

if cmder.server
	app = require './server'
else
	app = require './client'

app conf
