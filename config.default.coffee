module.exports =
	local_dir: 'local_dir'
	remote_dir: 'remote_dir'
	host: '127.0.0.1'
	port: 8345
	pattern: '**'
	polling_interval: 500
	password: null
	algorithm: 'aes128'
	on_change: (type, path, old_path) ->
