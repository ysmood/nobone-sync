nokit = require 'nokit'

module.exports = (task, option) ->
	task 'default build', ->
		nokit.require 'drives'
		nokit.warp '*.coffee'
			.load nokit.drives.auto 'compile'
		.run()

	task 'test', ->
		require './test/basic'