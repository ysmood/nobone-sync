{ kit } = require 'nobone'

try
	conf = require kit.path.join(process.cwd(), process.argv[4])
catch
	conf = {}
kit._.defaults conf, require('./config.default')

if process.argv[3] == '-s'
	app = require './server'
else
	app = require './client'

app conf
