'use strict'
httpFetch = do ->
	# check requirements
	# {{{
	api = {}
	api[typeof fetch] = true
	api[typeof AbortController] = true
	api[typeof Proxy] = true
	if api['undefined']
		console.log 'httpFetch: missing requirements'
		return null
	# }}}
	# initialize
	defaults = # {{{
		timeout: 20
		only200: true
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
		@body    = null
		@signal  = null
	# }}}
	FetchError = do -> # {{{
		if Error.captureStackTrace
			FE = (message, status) !->
				@name    = 'FetchError'
				@message = message
				@status  = status
				Error.captureStackTrace @, FetchError
		else
			FE = (message, status) !->
				@name    = 'FetchError'
				@message = message
				@status  = status
				@stack   = (new Error message).stack
		###
		FE.prototype = Error.prototype
		return FE
	# }}}
	responseHandler = (r) -> # {{{
		# initial response handler
		# check for HTTP status
		if not r.ok or (r.status != 200 and defaults.only200)
			throw new FetchError r.statusText, r.status
		# convert response to text because .json() with empty body
		# may throw an error in case of no-cors opaque mode (I dont need that bullshit)
		return r.text!.then (r) ->
			# parse non-empty as JSON
			if r
				try
					return JSON.parse r
				catch e
					throw new Error 'Incorrect response body: '+e.message+': '+r
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
