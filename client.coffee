# Watch and sync a local folder with a remote one.
# All the local operations will be repeated on the remote.
#
# This this the local watcher.

kit = require 'nokit'
cs = kit.require 'colors/safe'

isDir = (path)->
	path[-1..] == kit.path.sep

module.exports = (conf, watch = true) ->
	kit._.defaults conf, require('./config.default')

	process.env.pollingWatch = conf.pollingInterval

	watchHandler = (type, path, oldPath, stats) ->
		kit.log cs.cyan(type) + ': ' + path +
			(if oldPath then cs.cyan(' <- ') + oldPath else '')

		remotePath = kit.path.join(
				conf.remoteDir
				kit.path.relative(conf.localDir, path)
				if isDir(path) then '/' else ''
			)

		send { conf, path, type, remotePath, oldPath, stats }
		.then ->
			conf.onChange?.call 0, type, path, oldPath, stats
		.catch (err) ->
			kit.log cs.red err.stack

	push = (path, stats) ->
		watchHandler 'create', path, null, stats

	if watch
		kit.watchDir conf.localDir, {
			patterns: conf.pattern
			handler: watchHandler
		}
		.then (list) ->
			kit.log cs.cyan('Watched: ') + kit._.keys(list).length
		.catch (err) ->
			kit.log cs.red err.stack
	else
		conf.glob = conf.localDir
		kit.lstat conf.localDir
		.then (stat)->
			if stat.isDirectory()
				if kit._.isString conf.pattern
					conf.pattern = [conf.pattern]
				conf.glob = conf.pattern.map (p) ->
					if p[0] == '!'
						'!' + kit.path.join(conf.localDir, p[1..])
					else
						kit.path.join conf.localDir, p
		, (err)->
			kit.Promise.resolve(err)
		.then ->
			kit.glob conf.glob,
				all: true
				iter: (info) ->
					if !info.isDir
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

			if conf.password
				rdata.reqData = kit.encrypt opts.source, conf.password, conf.algorithm
				crypto = kit.require 'crypto', __dirname
				rdata.resPipe = crypto.createDecipher conf.algorithm, conf.password
				rdata.resPipe.pipe process.stdout if opts.isPipeToStdout
			else
				{ PassThrough } = kit.require 'stream', __dirname
				rdata.reqData = opts.source
				rdata.resPipe = new PassThrough

			data = new Buffer 0
			rdata.resPipe.on 'data', (chunk) ->
				process.stdout.write chunk if not conf.password
				data = Buffer.concat [data, chunk]

			rdata.url += encodeInfo operationInfo
			return kit.request rdata
			.then -> data

	p = p.then ->
		rdata.url += encodeInfo operationInfo
		kit.request rdata
	.then (res) ->
		if res.statusCode == 200
			kit.log cs.green('Synced: ') + opts.path
		else
			kit.log res.body
