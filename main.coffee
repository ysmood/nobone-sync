{ kit } = require 'nobone'

if process.argv[3] == '-s'
	require './server'
else
	try
		conf = require kit.path.join(__dirname, process.argv[4])
	catch
		conf = {}
	kit._.defaults conf, require('./config.default')

	client = require './client'
	client conf