client = require '../client'
server = require '../server'
{ kit } = require 'nobone'

now = Date.now() + ''

conf = {
	local_dir: 'test/local'
	remote_dir: 'test/remote'
	host: '127.0.0.1'
	port: 8345
	pattern: '**'
	polling_interval: 500
	on_change: (type, path, old_path) ->
		setTimeout ->
			s = kit.fs.readFileSync 'test/remote/a.txt', 'utf8'
			kit.fs.removeSync 'test/local/a.txt'
			kit.fs.removeSync 'test/remote/a.txt'
			if s == now
				process.exit 0
			else
				kit.err 'Sync does not work!'.red
				process.exit 1
		, 500
}

client conf
server conf

setTimeout ->
	kit.fs.outputFileSync 'test/local/a.txt', now
, 500