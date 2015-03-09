# Watch and sync a local folder with a remote one.
# All the local operations will be repeated on the remote.
#
# This this the local watcher.

kit = require 'nokit'
kit.require 'colors'

is_dir = (path)->
	path[-1..] == '/'

module.exports = (conf, watch = true) ->
	kit._.defaults conf, require('./config.default')

	process.env.pollingWatch = conf.polling_interval

	encodeInfo = (info) ->
		str = JSON.stringify info
		if conf.password
			kit.encrypt str, conf.password, conf.algorithm
			.toString 'hex'
		else
			encodeURIComponent str

	sendReq = (file_path, type, remote_path, old_path, stats) ->
		operationInfo = { type, path: remote_path }
		rdata = {
			url: "http://#{conf.host}:#{conf.port}/"
			method: 'POST'
		}

		p = kit.Promise.resolve()

		switch type
			when 'create', 'modify'
				if not is_dir file_path
					operationInfo.mode = stats.mode
					rdata.reqPipe = kit.createReadStream file_path
					crypto = kit.require 'crypto', __dirname
					if conf.password
						cipher = crypto.createCipher 'aes128', conf.password
						rdata.reqPipe = rdata.reqPipe.pipe cipher
			when 'move'
				rdata.reqData = kit.path.join(
					conf.remote_dir
					old_path.replace(conf.local_dir, '').replace('/', '')
				)
				if conf.password
					rdata.reqData = kit.encrypt rdata.reqData,
						conf.password, conf.algorithm

		p = p.then ->
			rdata.url += encodeInfo operationInfo
			kit.request rdata
		.then (data) ->
			if data == 'ok'
				kit.log 'Synced: '.green + file_path
			else
				kit.log data
		.catch (err) ->
			kit.log err.stack.red

	watch_handler = (type, path, old_path, stats) ->
		kit.log type.cyan + ': ' + path +
			(if old_path then ' <- '.cyan + old_path else '')

		remote_path = kit.path.join(
				conf.remote_dir
				kit.path.relative(conf.local_dir, path)
				if is_dir(path) then '/' else ''
			)

		sendReq path, type, remote_path, old_path, stats
		.then ->
			conf.on_change?.call 0, type, path, old_path, stats

	push = (path)->
		file_name = if conf.base_dir then kit.path.relative conf.base_dir, path else kit.path.basename path

		remote_path = kit.path.join conf.remote_dir, file_name

		kit.log "Uploading file: ".green + file_name + ' to '.green + remote_path

		sendReq path, 'create', remote_path

	if watch
		kit.watchDir conf.local_dir, {
			patterns: conf.pattern
			handler: watch_handler
		}
		.then (list) ->
			kit.log 'Watched: '.cyan + kit._.keys(list).length
		.catch (err) ->
			kit.log err.stack.red
	else
		conf.glob = conf.local_dir
		kit.lstat conf.local_dir
		.then (stat)->
			if stat.isDirectory()
				conf.base_dir = kit.path.dirname conf.local_dir
				if conf.local_dir.slice(-1) is '/'
					conf.glob = conf.local_dir + '**/*'
				else
					conf.glob = conf.local_dir + '/**/*'
		, (err)->
			kit.Promise.resolve()
		.then ->
			kit.glob conf.glob,
				nodir: true
				dot: true
		.then (paths)->
			paths.forEach push
