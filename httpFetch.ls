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
	Config = !-> # {{{
		@baseUrl = ''
		@timeout = 20
		@only200 = true
		@headers = null
	# }}}
	FetchOptions = (method) !-> # {{{
		@method  = method
		@body    = null
		@signal  = null
		@headers =
			'Accept': 'application/json'
			'Content-Type': 'application/json'
	# }}}
	FetchError = do -> # {{{
		if Error.captureStackTrace
			E = (message, status) !->
				@name    = 'FetchError'
				@message = message
				@status  = status
				Error.captureStackTrace @, FetchError
		else
			E = (message, status) !->
				@name    = 'FetchError'
				@message = message
				@status  = status
				@stack   = (new Error message).stack
		###
		E.prototype = Error.prototype
		return E
	# }}}
	HandlerOptions = (url, method, timeout) !-> # {{{
		@url     = url
		@method  = method
		@data    = ''
		@timeout = timeout
	# }}}
	textParser = (r) -> # {{{
		# parse non-empty as a JSON
		if r
			try
				return JSON.parse r
			catch e
				throw new Error 'Incorrect response body: '+e.message+': '+r
		# empty
		return null
	# }}}
	fetchHandler = (config) -> # {{{
		responseHandler = (r) -> # {{{
			# initial response handler
			# check for HTTP status
			if not r.ok or (r.status != 200 and config.only200)
				throw new FetchError r.statusText, r.status
			# convert response to text because .json() with empty body
			# may throw an error in case of no-cors opaque mode (I dont need that bullshit)
			return r.text!.then textParser
		# }}}
		return (options, callback) ->
			# prepare
			# check parameters
			if typeof! options != 'Object' or typeof callback != 'function'
				return null
			# determine method
			a = if options.hasOwnProperty 'method'
				then options.method
				else if options.data
					then 'POST'
					else 'GET'
			# create options
			o = new FetchOptions a
			# initialize
			# set headers
			if config.headers
				o.headers <<< config.headers
			if options.headers
				o.headers <<< options.headers
			# set data
			if options.data
				o.body = if typeof options.data == 'string'
					then options.data
					else JSON.stringify options.data
			# set abort signal
			aController = new AbortController!
			o.signal = aController.signal
			# determine timeout
			a = if options.hasOwnProperty 'timeout'
				then options.timeout
				else config.timeout
			# set timer
			if a >= 1
				timeout = setTimeout !->
					aController.abort!
				, 1000*a
			# determine url
			a = if options.url
				then config.baseUrl+options.url
				else config.baseUrl
			# run
			fetch a, o
				.then responseHandler
				.then (r) !->
					clearTimeout timeout if timeout
					callback true, r
				.catch (e) !->
					callback false, e
			# done
			return aController
	# }}}
	newInstance = (config) -> # {{{
		# prepare configuration
		c = new Config!
		for a of c when config.hasOwnProperty a
			c[a] = config[a]
		# create new handler
		h = fetchHandler c
		# initialize it
		h.config = c
		h.api = new Api h
		# create api proxy
		return new Proxy h, apiHandler
	# }}}
	Api = (handler) !-> # {{{
		@post = (url, data, callback) ->
			# prepare
			options = new HandlerOptions url, 'POST', handler.config.timeout
			options.data = data if data
			# execute
			return handler options, callback
		###
		@get = (url, callback) ->
			return handler (new HandlerOptions url, 'GET', handler.config.timeout), callback
		###
		@create = newInstance
	# }}}
	apiHandler = # {{{
		get: (me, key) ->
			# check method
			if typeof me.api[key] == 'function'
				return me.api[key]
			# check property
			if me.config.hasOwnProperty key
				return me.config[key]
			# nothing
			return null
		set: (me, key, val) ->
			# ...
			return true
	# }}}
	return newInstance new Config!
###
if httpFetch and typeof module != 'undefined'
	module.exports = httpFetch

