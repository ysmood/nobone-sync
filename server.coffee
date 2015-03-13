# Watch and sync a local folder with a remote one.
# All the local operations will be repeated on the remote.
#
# This this the remote server.


kit = require 'nokit'
kit.require 'colors'
http = require 'http'

localPath = (path) ->
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

		httpError = (code, err) ->
			kit.err err.stack or err
			res.statusCode = code
			res.end http.STATUS_CODES[code]

		try
			{ type, path, mode } = decodeInfo req.url[1..]
		catch err
			return httpError 400, err

		path = localPath path

		# Check if the path is allowed
		if conf.rootAllowed
			absPath = kit.path.normalize kit.path.resolve path
			absRoot = kit.path.normalize kit.path.resolve conf.rootAllowed
			if absPath.indexOf(absRoot) != 0
				return httpError 403, err

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

		pipeToFile = ->
			reqStream = getStream()
			kit.mkdirs kit.path.dirname path
			.then ->
				f = kit.createWriteStream path, { mode }
				f.on 'error', (err) ->
					p = kit.Promise.reject err
				reqStream.pipe f

		switch type
			when 'create'
				if path[-1..] == '/'
					p = kit.mkdirs path
				else
					p = pipeToFile()
			when 'modify'
				p = pipeToFile()

		if not reqStream
			data = new Buffer 0
			req.on 'data', (chunk) ->
				data = Buffer.concat [data, chunk]

		req.on 'error', (err) -> p = kit.Promise.reject err

		req.on 'end', ->
			oldPath = null

			switch type
				when 'create', 'modify'
					null
				when 'move'
					if conf.password and data.length > 0
						data = kit.decrypt data, conf.password, conf.algorithm

					oldPath = localPath data.toString()
					p = kit.move oldPath, path.replace(/\/+$/, '')
				when 'delete'
					p = kit.remove path
				else
					return httpError 404, new Error('Unknown Change Type')

			p.then ->
				kit.Promise.resolve(
					conf.onChange?.call 0, type, path, oldPath, mode
				)
			.then ->
				res.end 'ok'
			.catch (err) ->
				return httpError 500, err

	service.listen conf.port, ->
		kit.log "Listen: ".cyan + conf.port
