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
	kit._.defaults conf, require('./config.default')

	decodeInfo = (str) ->
		JSON.parse if conf.password
			kit.decrypt new Buffer(str, 'hex'), conf.password, conf.algorithm
		else
			decodeURIComponent str

	service = http.createServer (req, res) ->
		{ type, path, mode } = decodeInfo req.url[1..]

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

		reqStream = null
		getStream = ->
			if conf.password
				crypto = kit.require 'crypto', __dirname
				decipher = crypto.createDecipher conf.algorithm, conf.password
				req.pipe decipher
			else
				req

		switch type
			when 'create'
				if path[-1..] == '/'
					p = kit.mkdirs path
				else
					reqStream = getStream()
					p = kit.mkdirs kit.path.dirname path
					.then ->
						reqStream.pipe kit.createWriteStream path, { mode }
			when 'modify'
				reqStream = getStream()
				reqStream.pipe kit.createWriteStream path, { mode }

		if not reqStream
			data = new Buffer 0
			req.on 'data', (chunk) ->
				data = Buffer.concat [data, chunk]

		req.on 'end', ->
			old_path = null

			switch type
				when 'create', 'modify'
					null
				when 'move'
					if conf.password and data.length > 0
						data = kit.decrypt data, conf.password, conf.algorithm

					old_path = local_path data.toString()
					p = kit.move old_path, path.replace(/\/+$/, '')
				when 'delete'
					p = kit.remove path
				else
					res.statusCode = 404
					res.end 'Unknown Change Type'
					return

			p.then ->
				kit.Promise.resolve(
					conf.on_change?.call 0, type, path, old_path, mode
				)
			.then ->
				res.end 'ok'
			.catch (err) ->
				kit.err err
				res.statusCode = 500
				res.end http.STATUS_CODES[500]

	service.listen conf.port, ->
		kit.log "Listen: ".cyan + conf.port
