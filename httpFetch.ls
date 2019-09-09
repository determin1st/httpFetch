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
	Config = !-> # {{{
		@baseUrl   = ''
		@status200 = true
		@noEmpty   = false
		@timeout   = 20
		@retry     = null
		@headers   = null
	# }}}
	RetryOptions = !-> # {{{
		@count        = 15
		@current      = 0
		@expoBackoff  = true
		@maxBackoff   = 32
		@delay        = 1
	# }}}
	HandlerOptions = (url, method, config) !-> # {{{
		@url     = url
		@method  = method
		@data    = ''
		@timeout = config.timeout
		@retry   = config.retry
	# }}}
	HandlerData = !-> # {{{
		@aborter  = new AbortController!
		@timeout  = 0
		@timer    = 0
		@retry    = new RetryOptions!
	# }}}
	fetchHandler = (config) -> # {{{
		responseHandler = (r) -> # {{{
			# initial response handler
			# check for HTTP status
			if not r.ok or (r.status != 200 and config.status200)
				throw new FetchError r.statusText, r.status
			# convert response to text because .json() with empty body
			# may throw an error in case of no-cors opaque mode (I dont need that bullshit)
			return r.text!.then textParser
		# }}}
		textParser = (r) -> # {{{
			# parse non-empty as a JSON
			if r
				try
					return JSON.parse r
				catch e
					throw new Error 'Incorrect response body: '+e.message+': '+r
			# empty
			return if config.noEmpty
				then {}
				else null
		# }}}
		handler = (url, options, data, callback) -> # {{{
			# set timer
			if data.timeout
				data.timer = setTimeout !->
					data.aborter.abort!
					data.timer = 0
				, data.timeout
			# run
			fetch url, options
				.then responseHandler
				.then (r) !->
					# stop timer
					if data.timer
						clearTimeout data.timer
						data.timer = 0
					# success
					if callback
						callback true, r
				.catch (e) !->
					# stop timer
					if data.timer
						clearTimeout data.timer
						data.timer = 0
					# failure
					if callback
						a = callback false, e
					else
						a = true
					# retry?
					if a and (a = data.retry).count and a.current < a.count
						# determine delay
						if a.expoBackoff
							# exponential backoff algorithm
							# https://cloud.google.com/storage/docs/exponential-backoff
							b = 2**a.current + Math.floor (1001 * Math.random!)
							b = a.maxBackoff if b > a.maxBackoff
						else
							# fixed delay
							if typeof a.delay == 'number'
								# simple
								b = 1000*a.delay
							else
								# gradual
								if a.current <= (b = a.delay.length - 1)
									b = 1000*a.delay[a.current]
								else
									b = 1000*a.delay[b]
						# increase current
						++a.current
						# set re-try
						setTimeout !->
							handler url, options, data, callback
						, b
		# }}}
		return (options, callback) ->
			# check parameters
			if typeof! options != 'Object'
				return null
			# determine method
			a = if options.hasOwnProperty 'method'
				then options.method
				else if options.data
					then 'POST'
					else 'GET'
			# create options and data
			o = new FetchOptions a
			d = new HandlerData!
			# initialize
			# set headers
			if config.headers
				o.headers <<< config.headers
			if options.headers
				o.headers <<< options.headers
			# set request data
			if options.data
				o.body = if typeof options.data == 'string'
					then options.data
					else JSON.stringify options.data
			# set aborter signal
			o.signal = d.aborter.signal
			# set timeout
			a = if options.hasOwnProperty 'timeout'
				then options.timeout
				else config.timeout
			if a >= 1
				d.timeout = 1000 * a
			# set retry
			# {{{
			# copy configuration
			a = d.retry
			if b = config.retry
				for c of a
					a[c] = b[c]
			# copy user options
			if options.hasOwnProperty 'retry' and b = options.retry
				if typeof! b == 'Object'
					for c of a when b.hasOwnProperty c
						a[c] = b[c]
				else
					a.count = b
			# fix values
			a.current = 0
			a.maxBackoff = 1000 * a.maxBackoff
			# }}}
			# determine url
			a = if options.url
				then config.baseUrl+options.url
				else config.baseUrl
			# run
			handler a, o, d, callback
			# check
			if callback
				return d.aborter
			# create promise
			# TODO
			# ...
			return null
	# }}}
	newInstance = (base) -> (config) -> # {{{
		# create configuration
		c = new Config!
		# initialize it
		# set base
		if base
			for a of c
				c[a] = base[a]
		# set specified options
		for a of c when config.hasOwnProperty a
			c[a] = config[a]
		# create and initialize handler
		h = fetchHandler c
		h.config = c
		h.api = new Api h
		# create api
		return new Proxy h, apiHandler
	# }}}
	Api = (handler) !-> # {{{
		@post = (url, data, callback) ->
			# prepare
			options = new HandlerOptions url, 'POST', handler.config
			options.data = data if data
			# execute
			return handler options, callback
		###
		@get = (url, callback) ->
			return handler (new HandlerOptions url, 'GET', handler.config), callback
		###
		@create = newInstance handler.config
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
	return (newInstance null) new Config!
###
if httpFetch and typeof module != 'undefined'
	module.exports = httpFetch

