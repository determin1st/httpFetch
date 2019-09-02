'use strict'
httpFetch = do ->
	# check requirements
	# {{{
	api = {}
	api[typeof fetch] = true
	api[typeof AbortController] = true
	api[typeof Proxy] = true
	if api['undefined']
		return null
	# }}}
	# initialize
	defaults = # {{{
		timeout: 20
		headers:
			'Accept': 'application/json'
			'Content-Type': 'application/json'
	# }}}
	HandlerOptions = (url, method) !-> # {{{
		@url     = url
		@method  = method
		@data    = ''
		@timeout = defaults.timeout
	# }}}
	FetchOptions = (method) !-> # {{{
		@method  = method
		@headers = defaults.headers
		@body    = ''
		@signal  = null
	# }}}
	responseHandler = (r) -> # {{{
		# initial response handler
		# text conversion is used because .json() with empty body
		# may throw an error in case of no-cors opaque mode (I dont need that bullshit)
		return r.text!.then (r) ->
			if r
				# parse non-empty to JSON
				try
					return JSON.parse r
				catch e
					throw new Error 'Incorrect server response: '+e.message+': '+r
			# empty
			return null
	# }}}
	handler = (opts, callback) -> # {{{
		# check parameters
		if typeof! opts != 'Object' or typeof callback != 'function'
			return false
		# determine method
		if opts.hasOwnProperty 'method'
			a = opts.method
		else if opts.data
			a = 'POST'
		else
			a = 'GET'
		# create options
		o = new FetchOptions a
		# initialize
		# set data
		if opts.data
			o.body = if typeof opts.data == 'string'
				then opts.data
				else JSON.stringify opts.data
		# set timeout
		a = if opts.hasOwnProperty 'timeout'
			then opts.timeout
			else defaults.timeout
		if a >= 1
			# set controller
			abrt = new AbortController!
			o.signal = abrt.signal
			# set timer
			timeout = setTimeout !->
				abrt.abort!
			, 1000*a
		# execute
		debugger
		fetch opts.url, o
			.then responseHandler
			.then (r) !->
				clearTimeout timeout if timeout
				callback true, r
			.catch (e) !->
				callback false, e
		# done
		return true
	# }}}
	api = # {{{
		post: (url, data, callback) ->
			# prepare options
			o = new HandlerOptions url, 'POST'
			o.data = data if data
			# execute
			return handler o, callback
		get: (url, callback) ->
			return handler (new HandlerOptions url, 'GET'), callback
	# }}}
	return new Proxy handler, {
		get: (me, key) ->
			# check method
			if api.hasOwnProperty key
				return api[key]
			# nothing
			return null
		set: (me, key, val) ->
			# ...
			return true
	}
###
if httpFetch and typeof module != 'undefined'
	module.exports = httpFetch
