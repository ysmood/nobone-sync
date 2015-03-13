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

	encodeInfo = (info) ->
		str = JSON.stringify info
		if conf.password
			kit.encrypt str, conf.password, conf.algorithm
			.toString 'hex'
		else
			encodeURIComponent str

	sendReq = (filePath, type, remotePath, oldPath, stats) ->
		operationInfo = { type, path: remotePath }
		rdata = {
			url: "http://#{conf.host}:#{conf.port}/"
			method: 'POST'
		}

		p = kit.Promise.resolve()

		switch type
			when 'create', 'modify'
				if not isDir filePath
					operationInfo.mode = stats.mode
					rdata.reqPipe = kit.createReadStream filePath
					crypto = kit.require 'crypto', __dirname
					if conf.password
						cipher = crypto.createCipher 'aes128', conf.password
						rdata.reqPipe = rdata.reqPipe.pipe cipher
			when 'move'
				rdata.reqData = kit.path.join(
					conf.remoteDir
					oldPath.replace(conf.localDir, '').replace('/', '')
				)
				if conf.password
					rdata.reqData = kit.encrypt rdata.reqData,
						conf.password, conf.algorithm

		p = p.then ->
			rdata.url += encodeInfo operationInfo
			kit.request rdata
		.then (data) ->
			if data == 'ok'
				kit.log 'Synced: '.green + filePath
			else
				kit.log data
		.catch (err) ->
			kit.log err.stack.red

	watchHandler = (type, path, oldPath, stats) ->
		kit.log type.cyan + ': ' + path +
			(if oldPath then ' <- '.cyan + oldPath else '')

		remotePath = kit.path.join(
				conf.remoteDir
				kit.path.relative(conf.localDir, path)
				if isDir(path) then '/' else ''
			)

		sendReq path, type, remotePath, oldPath, stats
		.then ->
			conf.onChange?.call 0, type, path, oldPath, stats

	push = (path, stats) ->
		fileName = if conf.baseDir then kit.path.relative conf.baseDir, path else kit.path.basename path

		remotePath = kit.path.join conf.remoteDir, fileName

		kit.log "Uploading file: ".green + fileName + ' to '.green + remotePath

		sendReq path, 'create', remotePath, null, stats

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
