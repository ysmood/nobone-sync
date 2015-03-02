# Watch and sync a local folder with a remote one.
# All the local operations will be repeated on the remote.
#
# This this the remote server.


nobone = require 'nobone'

{ kit, service } = nobone()

local_path = (path) ->
	if process.platform == 'win32'
		path.replace /\//g, '\\'
	else
		path.replace /\\/g, '\/'

module.exports = (conf) ->
	service.post '/:type/:path', (req, res) ->
		type = req.params.type
		path = local_path req.params.path

		kit.log "[server] ".grey + type.cyan + ': ' + path

		data = new Buffer(0)
		req.on 'data', (chunk) ->
			data = Buffer.concat [data, chunk]

		req.on 'end', ->
			old_path = null
			switch req.params.type
				when 'create'
					if path[-1..] == '/'
						p = kit.mkdirs(path)
					else
						p = kit.outputFile path, data
				when 'modify'
					p = kit.outputFile path, data
				when 'move'
					old_path = local_path(data.toString())
					p = kit.move old_path, path.replace(/\/+$/, '')
				when 'delete'
					p = kit.remove path
				else
					res.status(403).end 'unknown_type'
					return

			p.then ->
				kit.Promise.resolve conf.on_change?.call 0, type, path, old_path
			.then ->
				res.send 'ok'
			.catch (err) ->
				kit.err err
				res.status(500).end err.stack

	service.listen conf.port, ->
		kit.log "Listen: ".cyan + conf.port
