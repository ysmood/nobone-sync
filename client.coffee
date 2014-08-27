# Watch and sync a local folder with a remote one.
# All the local operations will be repeated on the remote.
#
# This this the local watcher.

nobone = require 'nobone'
{ kit } = nobone()

process.env.watch_persistent = 'on'

module.exports = (conf) ->
	kit.watch_dir {
		dir: conf.local_dir
		pattern: conf.pattern
		handler: (type, path, old_path) ->
			kit.log type.cyan + ': ' + path +
				(if old_path then ' <- '.cyan + old_path else '')

			remote_path = encodeURIComponent(
				kit.path.join conf.remote_dir, path.replace(conf.local_dir, '').replace('/', '')
			)
			rdata = {
				url: 'http://' + conf.host + "/#{type}/#{remote_path}"
				method: 'POST'
			}

			p = kit.Q()

			switch type
				when 'create', 'modify'
					if path[-1..] != '/'
						p = p.then ->
							kit.readFile path
						.then (data) ->
							rdata.req_data = data
				when 'move'
					rdata.req_data = kit.path.join(
						conf.remote_dir
						old_path.replace(conf.local_dir, '').replace('/', '')
					)

			p = p.then ->
				kit.request rdata
			.then (data) ->
				if data == 'ok'
					kit.log 'Synced: '.green + path
				else
					kit.err data
			.catch (err) ->
				kit.err err
	}
	.then (list) ->
		kit.log 'Watched: '.cyan + kit._.keys(list).length
	.catch (err) ->
		kit.err err
