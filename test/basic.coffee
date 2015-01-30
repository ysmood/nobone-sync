client = require '../client'
server = require '../server'
{ kit } = require 'nobone'

now = Date.now() + ''

modifyPassed = false

conf = {
	local_dir: 'test/local'
	remote_dir: 'test/remote'
	host: '127.0.0.1'
	port: 8345
	pattern: ['**']
	polling_interval: 30
	on_change: (type, path, old_path) ->
		if path == 'test/local/b.css'
			if type == 'modify'
				modifyPassed = true

		if path == 'test/local/dir/a.txt'
			setTimeout ->
				s = kit.fs.readFileSync 'test/remote/dir/a.txt', 'utf8'
				if modifyPassed and s == now
					process.exit 0
				else
					kit.err 'Sync does not work!'.red
					process.exit 1
			, 500
}

client conf
server conf

setTimeout ->
	kit.fs.touchSync 'test/local/b.css'
, 400

setTimeout ->
	kit.fs.outputFileSync 'test/local/dir/a.txt', now
, 500

process.on 'exit', ->
	kit.fs.removeSync 'test/local/dir/a.txt'
	kit.fs.removeSync 'test/remote/dir/a.txt'
