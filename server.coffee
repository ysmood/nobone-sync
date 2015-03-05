# Watch and sync a local folder with a remote one.
# All the local operations will be repeated on the remote.
#
# This this the remote server.


kit = require 'nokit'
kit.require 'colors'
http = require 'http'

local_path = (path) ->
	if process.platform == 'win32'
		path.replace /\//g, '\\'
	else
		path.replace /\\/g, '\/'


module.exports = (conf) ->
	service = http.createServer (req, res) ->
		[nil, type, path] = req.url.match /\/(\w+)\/(\w+)/i

		if conf.password
			path = new Buffer path, 'hex'
			path = kit.decrypt(path, conf.password).toString()

		path = local_path path

		# Check if the path is allowed
		if conf.remote_dir
			absPath = kit.path.normalize kit.path.resolve path
			absRoot = kit.path.normalize kit.path.resolve conf.remote_dir
			if absPath.indexOf(absRoot) != 0
				res.statusCode = 403
				return res.end http.STATUS_CODES[403]

		kit.log "[server] ".grey + type.cyan + ': ' + path

		p = kit.Promise.resolve()

		reqStream = if conf.password
			crypto = kit.require 'crypto', __dirname
			decipher = crypto.createDecipher 'aes128', conf.password
			req.pipe decipher
		else
			data = new Buffer 0
			req.on 'data', (chunk) ->
				data = Buffer.concat [data, chunk]
			req

		switch type
			when 'create'
				if path[-1..] == '/'
					p = kit.mkdirs path
				else
					reqStream = reqStream.pipe kit.createWriteStream path
			when 'modify'
				reqStream = reqStream.pipe kit.createWriteStream path

		req.on 'end', ->
			old_path = null

			switch type
				when 'create', 'modify'
					null
				when 'move'
					if conf.password and data.length > 0
						data = kit.decrypt data, conf.password

					old_path = local_path data.toString()
					p = kit.move old_path, path.replace(/\/+$/, '')
				when 'delete'
					p = kit.remove path
				else
					res.statusCode = 403
					res.end 'unknown_type'
					return

			p.then ->
				kit.Promise.resolve conf.on_change?.call 0, type, path, old_path
			.then ->
				res.end 'ok'
			.catch (err) ->
				kit.err err
				res.statusCode = 500
				res.end()

	service.listen conf.port, ->
		kit.log "Listen: ".cyan + conf.port
