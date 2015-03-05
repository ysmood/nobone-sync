# Watch and sync a local folder with a remote one.
# All the local operations will be repeated on the remote.
#
# This this the remote server.


nobone = require 'nobone'
http = require 'http'

{ kit, service } = nobone()
kit.require 'colors'

local_path = (path) ->
	if process.platform == 'win32'
		path.replace /\//g, '\\'
	else
		path.replace /\\/g, '\/'


module.exports = (conf) ->
	service.post '/:type/:path', (req, res) ->
		type = req.params.type
		path = req.params.path

		if conf.password
			path = new Buffer path, 'hex'
			path = kit.decrypt(path, conf.password).toString()

		path = local_path path

		# Check if the path is allowed
		if conf.remote_dir
			absPath = kit.path.normalize kit.path.resolve path
			absRoot = kit.path.normalize kit.path.resolve conf.remote_dir
			if absPath.indexOf(absRoot) != 0
				return res.status(403).end http.STATUS_CODES[403]

		kit.log "[server] ".grey + type.cyan + ': ' + path

		data = new Buffer(0)
		req.on 'data', (chunk) ->
			data = Buffer.concat [data, chunk]

		req.on 'end', ->
			old_path = null

			if conf.password and data.length > 0
				data = kit.decrypt data, conf.password

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
