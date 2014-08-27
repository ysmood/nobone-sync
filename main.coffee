{ kit } = require 'nobone'

try
	conf = require kit.path.join(__dirname, process.argv[4])
catch
	conf = {}
kit._.defaults conf, require('./config.default')

if process.argv[3] == '-s'
	app = require './server'
else
	app = require './client'

app conf
