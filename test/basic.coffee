client = require '../client'
server = require '../server'
kit = require 'nokit'
{ Promise } = kit
kit.require 'colors'

now = Date.now() + ''

modifyPassed = false
createPassed = false
deletePassed = false
statsPassed = false
executePassed = false

conf = {
	localDir: 'test/local'
	remoteDir: 'test/remote'
	host: '127.0.0.1'
	port: 8345
	password: 'test'
	pattern: ['**']
	pollingInterval: 30
	onChange: (type, path, oldPath, stats) ->
		if path == 'test/local/b.css'
			if type == 'modify'
				modifyPassed = true

		if path == 'test/local/d'
			setTimeout ->
				deletePassed = not kit.existsSync 'test/remote/d'
			, 100

		if path == 'test/local/dir/path/a.txt'
			setTimeout ->
				s = kit.readFileSync 'test/remote/dir/path/a.txt', 'utf8'
				statsPassed = kit.statSync('test/remote/dir/path/a.txt')
					.mode.toString(8)[3] == '7'
				createPassed = s == now
				kit.log [modifyPassed, deletePassed, createPassed, statsPassed, executePassed]
				if modifyPassed and deletePassed and createPassed and
				statsPassed and executePassed
					process.exit 0
				else
					kit.err 'Sync does not work!'.red
					process.exit 1
			, 500
}

kit.touchSync 'test/local/d'
kit.touchSync 'test/remote/d'

client conf
server kit._.defaults {
	onChange: (type) ->
		if type == 'execute'
			executePassed = true

		new Promise (r) -> setTimeout r, 1
}, conf

setTimeout ->
	client.send {
		conf: conf
		remotePath: '.coffee'
		type: 'execute'
		source: ''' console.log 'OK' '''
	}
	.then (out) ->
		executePassed = out.toString() == 'OK\n'
, 100

setTimeout ->
	kit.touchSync 'test/local/b.css'
, 400

setTimeout ->
	kit.removeSync 'test/local/d'
, 500

setTimeout ->
	kit.outputFileSync 'test/local/dir/path/a.txt', now, { mode: 0o777 }
, 600

process.on 'exit', ->
	kit.removeSync 'test/local/dir/path'
	kit.removeSync 'test/remote/dir/path'
	kit.removeSync 'test/local/d'
