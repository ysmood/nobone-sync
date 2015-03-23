# Watch and sync a local folder with a remote one.
# All the local operations will be repeated on the remote.
#
# This this the local watcher.

kit = require 'nokit'
kit.require 'colors'

isDir = (path)->
	path[-1..] == '/'

module.exports = (conf, watch = true) ->
	kit._.defaults conf, require('./config.default')

	process.env.pollingWatch = conf.pollingInterval

	watchHandler = (type, path, oldPath, stats) ->
		kit.log type.cyan + ': ' + path +
			(if oldPath then ' <- '.cyan + oldPath else '')

		remotePath = kit.path.join(
				conf.remoteDir
				kit.path.relative(conf.localDir, path)
				if isDir(path) then '/' else ''
			)

		send { conf, path, type, remotePath, oldPath, stats }
		.then ->
			conf.onChange?.call 0, type, path, oldPath, stats
		.catch (err) ->
			kit.log err.stack.red

	push = (path, stats) ->
		fileName = if conf.baseDir then kit.path.relative conf.baseDir, path else kit.path.basename path

		remotePath = kit.path.join conf.remoteDir, fileName

		kit.log "Uploading file: ".green + fileName + ' to '.green + remotePath

		send { conf, path, 'create', remotePath, stats }
		.catch (err) ->
			kit.log err.stack.red

	if watch
		kit.watchDir conf.localDir, {
			patterns: conf.pattern
			handler: watchHandler
		}
		.then (list) ->
			kit.log 'Watched: '.cyan + kit._.keys(list).length
		.catch (err) ->
			kit.log err.stack.red
	else
		conf.glob = conf.localDir
		kit.lstat conf.localDir
		.then (stat)->
			if stat.isDirectory()
				conf.baseDir = kit.path.dirname conf.localDir
				if conf.localDir.slice(-1) is '/'
					conf.glob = conf.localDir + '**/*'
				else
					conf.glob = conf.localDir + '/**/*'
		, (err)->
			kit.Promise.resolve()
		.then ->
			kit.glob conf.glob,
				nodir: true
				dot: true
				iter: (info) ->
					push info.path, info.stats

###*
 * Send single request.
 * @param  {Object} opts Defaults:
 * ```coffee
 * { conf, path, type, remotePath, oldPath, stats }
 * ```
 * @return {Promise}
###
module.exports.send = send = (opts) ->
	conf = opts.conf
	opts.isPipeToStdout ?= true

	encodeInfo = (info) ->
		str = if kit._.isString info
			info
		else
			JSON.stringify info

		if conf.password
			kit.encrypt str, conf.password, conf.algorithm
			.toString 'hex'
		else
			encodeURIComponent str

	operationInfo = { type: opts.type, path: opts.remotePath }
	rdata = {
		url: "http://#{conf.host}:#{conf.port}/"
		method: 'POST'
		body: false
	}

	p = kit.Promise.resolve()

	switch opts.type
		when 'create', 'modify'
			if not isDir opts.path
				if opts.stats
					operationInfo.mode = opts.stats.mode

				rdata.reqPipe = kit.createReadStream opts.path
				crypto = kit.require 'crypto', __dirname
				if conf.password
					cipher = crypto.createCipher 'aes128', conf.password
					rdata.reqPipe = rdata.reqPipe.pipe cipher
		when 'move'
			rdata.reqData = kit.path.join(
				conf.remoteDir
				opts.oldPath.replace(conf.localDir, '').replace('/', '')
			)
			if conf.password
				rdata.reqData = kit.encrypt rdata.reqData,
					conf.password, conf.algorithm

		when 'execute'
			rdata.reqData = kit.encrypt opts.source, conf.password, conf.algorithm

			if conf.password
				crypto = kit.require 'crypto', __dirname
				rdata.resPipe = crypto.createDecipher conf.algorithm, conf.password
				rdata.resPipe.pipe process.stdout if opts.isPipeToStdout
			else
				rdata.resPipe = process.stdout if opts.isPipeToStdout

			data = new Buffer 0
			rdata.resPipe.on 'data', (chunk) ->
				data = Buffer.concat [data, chunk]

			rdata.url += encodeInfo operationInfo
			return kit.request rdata
			.then -> data

	p = p.then ->
		rdata.url += encodeInfo operationInfo
		kit.request rdata
	.then (res) ->
		if res.statusCode == 200
			kit.log 'Synced: '.green + opts.path
		else
			kit.log res.body
