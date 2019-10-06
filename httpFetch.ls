'use strict'
httpFetch = do ->
	# check requirements
	# {{{
	api = [
		typeof fetch
		typeof AbortController
		typeof Proxy
	]
	if api.includes 'undefined'
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
			'Content-Type': 'application/json; charset=UTF-8'
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
		@aborter  = null
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
		newFormData = do -> # {{{
			# prepare recursive helper function
			add = (data, item, key) ->
				# check type
				switch typeof! item
				case 'Object'
					# object's own properties are iterated
					# with the respect to definition order (top to bottom)
					t = Object.getOwnPropertyNames item
					if key
						for k in t
							add data, item[k], key+'['+k+']'
					else
						for k in t
							add data, item[k], k
				case 'Array'
					# the data parameter may be array itself,
					# in this case it is unfolded to a set of parameters,
					# otherwise, additional brackets are added to the name,
					# which is common (for example, to PHP parser)
					t = item.length
					k = -1
					if key
						while ++k < t
							add data, item[k], key+'[]'
					else
						while ++k < t
							add data, item[k], ''
				case 'HTMLInputElement'
					# file inputs are unfolded to FileLists
					if item.type == 'file' and t = item.files.length
						add data, item.files, key
				case 'FileList'
					# similar to the Array
					if (t = item.length) == 1
						data.append key, item.0
					else
						k = -1
						while ++k < t
							data.append key+'[]', item[k]
				case 'Null'
					# null will become 'null' string when appended,
					# which is not expected(?!) in most cases, so,
					# let's cast it to the empty string!
					data.append key, ''
				default
					data.append key, item
				# done
				return data
			# create simple factory
			return (o) ->
				return add new FormData!, o, ''
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
			# {{{
			if options.data
				# check content type
				a = o.headers['Content-Type']
				switch 0
				case a.indexOf 'application/json'
					# create JSON
					o.body = if typeof options.data == 'string'
						then options.data
						else JSON.stringify options.data
				case a.indexOf 'multipart/form-data'
					# create FormData
					o.body = if typeof! options.data == 'FormData'
						then options.data
						else newFormData options.data
					# remove type header,
					# because, it conflicts with FormData object body,
					# despite they are equal (wtf)
					delete o.headers['Content-Type']
				default
					o.body = options.data if options.data
			# }}}
			# set aborter
			d.aborter = if options.aborter
				then options.aborter
				else new AbortController!
			# set abort signal
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

# vim: ts=2 sw=2 sts=2 fdm=marker:
