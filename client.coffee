# Watch and sync a local folder with a remote one.
# All the local operations will be repeated on the remote.
#
# This this the local watcher.

nobone = require 'nobone'
{ kit } = nobone()

module.exports = (conf, watch = true) ->
	process.env.pollingWatch = conf.polling_interval

	watch_handler = (type, path, old_path) ->
		conf.on_change?.apply 0, arguments

		kit.log type.cyan + ': ' + path +
			(if old_path then ' <- '.cyan + old_path else '')

		is_dir = path[-1..] == '/'

		remote_path = encodeURIComponent(
			kit.path.join(
				conf.remote_dir
				kit.path.relative(conf.local_dir, path)
				if is_dir then '/' else ''
			)
		)
		rdata = {
			url: "http://#{conf.host}:#{conf.port}/#{type}/#{remote_path}"
			method: 'POST'
		}

		p = kit.Promise.resolve()

		switch type
			when 'create', 'modify'
				if not is_dir
					p = p.then ->
						kit.readFile path
					.then (data) ->
						rdata.reqData = data
			when 'move'
				rdata.reqData = kit.path.join(
					conf.remote_dir
					old_path.replace(conf.local_dir, '').replace('/', '')
				)

		p = p.then ->
			kit.request rdata
		.then (data) ->
			if data == 'ok'
				kit.log 'Synced: '.green + path
			else
				kit.log data
		.catch (err) ->
			kit.log err.stack.red

	if watch
		kit.watchDir {
			dir: conf.local_dir
			pattern: conf.pattern
			handler: watch_handler
		}
		.then (list) ->
			kit.log 'Watched: '.cyan + kit._.keys(list).length
		.catch (err) ->
			kit.log err.stack.red
	else
		kit.lstat conf.local_dir
		.then (stat)->
			if stat.isDirectory()
				if conf.local_dir.slice(-1) is '/'
					conf.glob = conf.local_dir + '**/*'
				else
					conf.glob = conf.local_dir + '/**/*'
			else
				conf.glob = conf.local_dir
				conf.local_dir = kit.path.dirname conf.local_dir
			kit.glob conf.glob,
				nodir: true
				dot: true
		.then (paths)->
			paths.forEach (file)->
				watch_handler 'create', file