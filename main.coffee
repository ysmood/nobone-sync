{ kit } = require 'nobone'

try
	conf = require kit.path.join(process.cwd(), process.argv[3])
catch
	kit.log 'No config specified, use default config.'.yellow
	conf = {}
kit._.defaults conf, require('./config.default')

if process.argv[3] == '-s'
	app = require './server'
else
	app = require './client'

app conf
