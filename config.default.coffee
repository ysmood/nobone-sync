module.exports =
	localDir: 'localDir'
	remoteDir: 'remoteDir'
	host: '127.0.0.1'
	port: 8345
	pattern: '**'
	pollingInterval: 500
	password: null
	algorithm: 'aes128'
	onChange: (type, path, oldPath) ->
