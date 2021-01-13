"use strict"
httpFetch = do ->
	# check requirements
	consoleError = (msg) !-> # {{{
		a = '%chttpFetch: %c'+msg
		console.log a, 'font-weight:bold;color:gold', 'color:orangered;font-size:140%'
	# }}}
	# {{{
	Api = [
		typeof fetch
		typeof AbortController
		typeof TextDecoder
		typeof Proxy
		typeof Promise
		typeof WeakMap
		typeof ReadableStream
	]
	if Api.includes 'undefined'
		consoleError 'missing requirements'
		return null
	# }}}
	# helpers
	jsonDecode = (s) -> # {{{
		if s
			try
				# parses non-empty string as JSON
				return JSON.parse s
			catch
				# breaks to upper level!
				throw new FetchError 1, 'incorrect JSON: '+s
		# empty equals to null
		return null
	# }}}
	jsonEncode = (o) -> # {{{
		try
			return JSON.stringify o
		catch null
			return null
	# }}}
	textDecode = do -> # {{{
		t = new TextDecoder 'utf-8'
		return (buf) ->
			t.decode buf
	# }}}
	textEncode = do -> # {{{
		t = new TextEncoder!
		return (str) ->
			t.encode str
	# }}}
	apiCrypto = do -> # {{{
		# check requirements
		if (typeof crypto == 'undefined') or not crypto.subtle
			consoleError 'Web Crypto API is not available'
			return null
		# helpers
		CS = crypto.subtle
		nullFunc = -> null
		bufToHex = do -> # {{{
			# create conversion array
			hex = []
			i = -1
			n = 256
			while ++i < n
				hex[i] = i.toString 16 .padStart 2, '0'
			# create function
			return (buf) ->
				a = new Uint8Array buf
				b = []
				i = -1
				n = a.length
				while ++i < n
					b[i] = hex[a[i]]
				return b.join ''
		# }}}
		hexToBuf = (hex) -> # {{{
			# align hex string length
			if (len = hex.length) % 2
				hex = '0' + hex
				++len
			# determine buffer length
			len = len / 2
			# create buffer
			buf = new Uint8Array len
			# convert hex pairs to integers and
			# put them inside the buffer one by one
			i = -1
			j = 0
			while ++i < len
				buf[i] = parseInt (hex.slice j, j + 2), 16
				j += 2
			# done
			return buf
		# }}}
		bufToBigInt = (buf) -> # {{{
			return BigInt '0x' + (bufToHex buf)
		# }}}
		bigIntToBuf = (bi, size) -> # {{{
			# convert BigInt to buffer
			buf = hexToBuf bi.toString 16
			# check buffer length
			if not size or (len = buf.length) == size
				return buf
			# align buffer length to specified size
			if len > size
				# truncate
				buf = buf.slice len - size
			else
				# pad
				big = new Uint8Array size
				big.set buf, size - len
				buf = big
			# done
			return buf
		# }}}
		# singleton
		return {
			# {{{
			cs: CS
			secretManagersPool: new WeakMap!
			keyParams: {
				name: 'ECDH'
				namedCurve: 'P-521'
			}
			derivePublicKey: {
				name: 'HMAC'
				hash: 'SHA-512'
				length: 528
			}
			deriveParams: {
				name: 'HMAC'
				hash: 'SHA-512'
				length: 528
			}
			# }}}
			generateKeyPair: ->> # {{{
				# create keys
				k = await (CS.generateKey @keyParams, true, ['deriveKey'])
					.catch nullFunc
				# check
				return null if k == null
				# convert public CryptoKey
				a = await (CS.exportKey 'spki', k.publicKey)
					.catch nullFunc
				# check
				return if a == null
					then null
					else [k.privateKey, a]
			# }}}
			generateHashPair: ->> # {{{
				# create first hash
				a = await (CS.generateKey @deriveParams, true, ['sign'])
					.catch nullFunc
				# check
				return null if a == null
				# convert CryptoKey
				a = await (CS.exportKey 'raw', a)
					.catch nullFunc
				# check
				return null if a == null
				# create second hash
				b = await (CS.digest 'SHA-512', a)
					.catch nullFunc
				# check
				return null if b == null
				# done
				a = new Uint8Array a
				b = new Uint8Array b
				return [a, b]
			# }}}
			importKey: (k) -> # {{{
				return (CS.importKey 'spki', k, @keyParams, true, [])
					.catch nullFunc
			# }}}
			importEcdhKey: (k) -> # {{{
				return (CS.importKey 'raw', k, {name: 'AES-GCM'}, false, ['encrypt' 'decrypt'])
					.catch nullFunc
			# }}}
			deriveKey: (privateK, publicK) -> # {{{
				publicK = {
					name: 'ECDH'
					public: publicK
				}
				return (CS.deriveKey publicK, privateK, @deriveParams, true, ['sign'])
					.catch nullFunc
			# }}}
			bufToBase64: (buf) -> # {{{
				a = new Uint8Array buf
				return btoa (String.fromCharCode.apply null, a)
			# }}}
			base64ToBuf: (str) -> # {{{
				# decode base64 to string
				a = atob str
				b = a.length
				# create buffer
				c = new Uint8Array b
				d = -1
				# populate
				while ++d < b
					c[d] = a.charCodeAt d
				# done
				return c
			# }}}
			newSecret: do -> # {{{
				# constructors
				CipherParams = (iv) !->
					@name      = 'AES-GCM'
					@iv        = iv
					@tagLength = 128
				CryptoData = (data, params) !->
					@data   = data
					@params = params
				SecretStorage = (manager, secret, key, iv) !->
					@manager = manager
					@secret  = secret
					@key     = key
					@params  = new CipherParams iv
				SecretStorage.prototype = {
					encrypt: (data, extended) -> # {{{
						# encode string to ArrayBuffer
						if typeof data == 'string'
							data = textEncode data
						# copy counter to avoid multiple calls collision
						p = new CipherParams @params.iv.slice!
						# encrypt data
						data = (CS.encrypt p, @key, data).catch nullFunc
						# check
						if extended
							# create new crypto object
							data = new CryptoData data, p
							# advance counter
							@next!
						# complete
						return data
					# }}}
					decrypt: (data, params) -> # {{{
						# encode string to ArrayBuffer
						if typeof data == 'string'
							data = textEncode data
						# check
						if not params
							return (CS.decrypt @params, @key, data).catch nullFunc
						# copy counter to avoid modification of the original
						params = new CipherParams params.iv.slice!
						# advance it
						@next params.iv
						# start decryption
						data = (CS.decrypt params, @key, data).catch nullFunc
						# create new crypto object
						return new CryptoData data, params
					# }}}
					next: (counter) -> # {{{
						# get counter
						a = if counter
							then counter
							else @params.iv
						b = new DataView a.buffer, 10, 2
						# convert private and public parts of the counter to integers
						c = bufToBigInt (a.slice 0, 10)
						d = b.getUint16 0, false
						# increase and fix overflows
						if (e = ++c - ``1208925819614629174706176n``) >= 0
							c = e
						if (e = ++d - 65536) >= 0
							d = e
						# store
						a.set (bigIntToBuf c, 10), 0
						b.setUint16 0, d, false
						# update secret
						if not counter
							@secret.set a, 32
						# complete
						return @
					# }}}
					tag: -> # {{{
						# serialize public part of the counter
						return bufToHex @secret.slice -2
					# }}}
					save: -> # {{{
						# encode and store secret data
						return if @manager 'set', apiCrypto.bufToBase64 @secret
							then @
							else null
					# }}}
					get: -> # {{{
						# serialize and return
						return apiCrypto.bufToBase64 @secret
					# }}}
				}
				# factory
				return (secret, manager) ->>
					# check
					switch typeof! secret
					case 'String'
						# from storage
						# decode from base64
						secret = apiCrypto.base64ToBuf secret
					case 'CryptoKey'
						# from handshake
						# convert to raw data
						secret = await apiCrypto.cs.exportKey 'raw', secret
						secret = new Uint8Array secret
						# trim leading zero-byte (!?)
						secret = secret.slice 1 if secret.0 == 0
						break
					default
						# incorrect type
						return null
					# check length
					if secret.length < 44
						return null
					# truncate
					secret = secret.slice 0, 44
					# extract parts
					# there is no reason to apply any hash algorithms,
					# because key resistance to preimages/collisions won't improve,
					k = secret.slice  0, 32    # 256bits (aes cipher key)
					c = secret.slice 32, 32+12 # 96bit (gcm counter/iv)
					# create CryptoKey object
					if (k = await apiCrypto.importEcdhKey k) == null
						return null
					# create storage
					return new SecretStorage manager, secret, k, c
			# }}}
		}
	# }}}
	parseArguments = (a) -> # {{{
		# check count
		if not a.length
			return new FetchError 3, 'no arguments'
		# check what syntax is used
		switch typeof! a.0
		case 'String'
			# Short syntax,
			# create options object for the lazy user
			switch a.length
			case 3
				# [url,data,callback]
				a.0 = {
					url:  a.0
					data: a.1
					method: 'POST'
				}
				a.1 = a.2
			case 2
				# [url,data/callback]
				if typeof a.1 == 'function'
					a.0 = {
						url: a.0
						method: 'GET'
					}
				else
					# this case allows to use undefined as an argument,
					# the request will be sent as POST with empty body
					a.0 = {
						url:  a.0
						data: a.1
						method: 'POST'
					}
					a.1 = false
			default
				# [url]
				a.0 = {
					url: a.0
					method: 'GET'
				}
				a.1 = false
			# continue the fall
			fallthrough
		case 'Object'
			# Default syntax: [options,callback]
			# check url
			if a.0.url and typeof a.0.url != 'string'
				return new FetchError 3, 'wrong url type'
			# check callback
			if a.1 and (typeof a.1 != 'function')
				return new FetchError 3, 'wrong callback type'
		default
			# Incorrect syntax
			return new FetchError 3, 'incorrect syntax'
		# done
		return a
	# }}}
	isFormData = (data) -> # {{{
		# check type
		switch typeof! data
		case 'Object'
			for a of data when isFormData data[a]
				return true
		case 'Array'
			b = data.length
			a = -1
			while ++a < b
				if isFormData data[a]
					return true
		case 'HTMLInputElement', 'FileList', 'File', 'Blob'
			return true
		# done
		return false
	# }}}
	# constructors
	FetchConfig = !-> # {{{
		@baseUrl        = ''
		@mounted        = false
		###
		@mode           = null
		@credentials    = null
		@cache          = null
		@redirect       = null
		@referrer       = null
		@referrerPolicy = null
		@integrity      = null
		@keepalive      = null
		###
		@status200      = true
		@notNull        = false
		@fullHouse      = false
		@promiseReject  = false
		@timeout        = 20
		@redirectCount  = 5
		@secret         = null
		@headers        = null
		@parseResponse  = 'data'
	###
	FetchConfig.prototype = {
		fetchOptions: [
			'mode'
			'credentials'
			'cache'
			'redirect'
			'referrer'
			'referrerPolicy'
			'integrity'
			'keepalive'
		]
		dataOptions: [
			'baseUrl'
			'timeout'
			'redirectCount'
			'parseResponse'
		]
		flagOptions: [
			'status200'
			'notNull'
			'fullHouse'
			'promiseReject'
		]
		setOptions: (o) !->
			# set aliases
			# in case of user mistyped config option
			# they should go first to be lower priority (may be overwritten)
			if o.hasOwnProperty 'baseURL'
				@baseUrl = o.baseURL
			# set unique
			if o.hasOwnProperty 'mounted'
				@mounted = !!o.mounted
			# set native
			for a in @fetchOptions when o.hasOwnProperty a
				@[a] = o[a]
			# set advanced
			for a in @dataOptions when o.hasOwnProperty a
				@[a] = o[a]
			# set flags
			for a in @flagOptions when o.hasOwnProperty a
				@[a] = !!o[a]
			# set headers
			if o.headers
				@setHeaders o.headers
			# done
		setHeaders: (s) !->
			# create if does not exist
			if not (h = @headers)
				@headers = h = {}
			# iterate
			for a,b of s
				# convert letter case for uniformity and set
				h[a.toLowerCase!] = b
			# done
	}
	# }}}
	FetchOptions = !-> # {{{
		@method         = 'GET'
		@headers        = {
			# explicit charset=utf-8 definition is not required and
			# should not be there for the sake of purity
			'content-type': 'application/json'
		}
		@body           = null
		@mode           = 'cors'
		@credentials    = 'same-origin'
		@cache          = 'default'
		@redirect       = 'follow'
		@referrer       = ''
		@referrerPolicy = ''
		@integrity      = ''
		@keepalive      = false
		@signal         = null
	###
	FetchOptions.prototype = {
		setHeaders: (s) !->
			# prepare
			h = @headers
			# iterate
			for a,b of s
				# convert letter case for uniformity
				a = a.toLowerCase!
				# check operation
				if not b
					# delete
					if h.hasOwnProperty a
						delete h[a]
				else
					# set
					h[a] = b
			# done
	}
	# }}}
	FetchError = do -> # {{{
		if Error.captureStackTrace
			FetchError = (id, message) !->
				@id       = id
				@message  = message
				@response = null
				@status   = 0
				Error.captureStackTrace @, FetchError
		else
			FetchError = (id, message) !->
				@id       = id
				@message  = message
				@response = null
				@status   = 0
				@stack    = (new Error message).stack
		###
		FetchError.prototype = Error.prototype
		return FetchError
	# }}}
	FetchData = do -> # {{{
		ResponseData = do ->
			RequestData = !-> # {{{
				@url     = ''
				@headers = null
				@data    = null
				@crypto  = null
				@time    = 0
			###
			RequestData.prototype = {
				setUrl: (base, url) !->
					if url
						if base and (url.indexOf ':') == -1
							@url = if base[base.length - 1] == '/' or url.0 == '/'
								then base + url
								else base + '/' + url
						else
							@url = url
					else
						@url = base
			}
			# }}}
			return ResponseData = !->
				@status  = 0
				@type    = ''
				@headers = null
				@data    = null
				@crypto  = null
				@time    = 0
				@request = new RequestData!
			###
		###
		RetryData = (count) !->
			@count   = count
			@current = 0
		###
		return FetchData = (config) !->
			# cumulative request configuration
			@status200     = config.status200
			@fullHouse     = config.fullHouse
			@notNull       = config.notNull
			@promiseReject = config.promiseReject
			@timeout       = 1000 * config.timeout
			@parseResponse = config.parseResponse
			# controllers and their data
			@callback  = null
			@promise   = null
			@response  = new ResponseData!
			@redirect  = new RetryData config.redirectCount
			@aborter   = null
			@timer     = 0
			@timerFunc = (force) !~>
				if force
					# stop timer
					clearTimeout @timer
				else
					# stop fetch
					@aborter.abort!
				@timer = 0
	# }}}
	FetchStream = do -> # {{{
		nullResolved = do -> # {{{
			return new Promise (resolve) !->
				resolve null
		# }}}
		StreamChunk = (size) !-> # {{{
			@dose = 0
			@data = if size
				then new Uint8Array size
				else null
		# }}}
		newStreamBuffer = (buf, pos) -> # {{{
			a = new StreamChunk 0
			a.data = buf
			a.dose = pos
			return a
		# }}}
		###
		FetchStream = (stream, data, sec) !->
			# ReadableStream wrapper
			# initialize private vars
			# {{{
			reader = stream.getReader! #getReader {mode: 'byob'}
			res    = data.response
			pause  = false
			locked = null
			chunk  = null
			buffer = null
			time   = 0
			size   = if res.headers['content-length']
				then parseInt res.headers['content-length']
				else 0
			# }}}
			# create helpers
			readStart = ~> # {{{
				# reset pause
				@paused = pause := false
				# reset last error
				@error = null
				# check canceled
				if not stream
					return nullResolved
				# store current timestamp
				time := performance.now!
				# start reading
				return reader.read!
					.then  readHandler, errorHandler
					.catch errorHandler # guard readHandler throws
			# }}}
			readHandler = (c) ~> # {{{
				# accumulate latency
				@latency += performance.now! - time
				@timing  += @latency
				# check canceled
				if not stream
					throw null
				# get chunk data
				c = if c.done
					then null
					else c.value
				# check paused
				if pause
					return pause.then ~>
						# reset pause
						@paused = pause := false
						# check canceled
						if not stream
							throw null
						# complete
						return readComplete c
				# complete
				return readComplete c
			# }}}
			errorHandler = (e) ~> # {{{
				# set error
				@error = if stream
					then new FetchError 0, 'stream failed: '+e.message
					else new FetchError 4, 'stream canceled'
				# done
				return null
			# }}}
			readComplete = (d) ~> # {{{
				###
				# assemble the chunk
				if chunk
					# prepare
					a = chunk.dose
					b = chunk.data.byteLength - a
					# check dose
					if d
						# new dose arrived
						# check the inflation
						if (c = d.byteLength) <= b
							# new dose fits into chunk
							# inject it
							chunk.data.set d, a
							# check for perfect fit
							if (chunk.dose = a + c) == b
								# exact assembly
								# set the result and
								# dispose the envelope
								d = chunk.data
								chunk := null
								# proceed to completion..
							else
								# partial assembly
								# repeat the read routine
								return readStart!
						else
							# overdose
							# inject partially
							chunk.data.set (d.subarray 0, b), a
							# allocate a buffer
							buffer := newStreamBuffer d, b
							# set the result and
							# dispose the envelope
							d = chunk.data
							chunk := null
							# proceed to completion..
					else
						# no more dosage
						# extract remains
						d = chunk.data.slice 0, a if a
						# dispose the envelope
						chunk := null
						# finish up
						@cancel!
				else if not d
					# finish up
					@cancel!
				###
				# unlock for the next read
				locked := null
				# update progress
				if size > 0
					if d
						@offset  += d.length
						@progress = @offset / size
					else
						@offset   = size
						@progress = 1
				# done
				return d
			# }}}
			readBufComplete = ~> # {{{
				# check canceled
				if not stream
					return null
				# get data
				d = chunk.data
				# dispose the envelope and
				# unlock for the next read
				chunk := locked := pause := null
				# update progress
				if size > 0
					@offset  += d.length
					@progress = @offset / size
				# done
				return d
			# }}}
			# create object shape
			# {{{
			@offset   = 0
			@progress = 0.00
			@latency  = 0
			@timing   = 0
			@error    = null
			@paused   = false
			@response = res  = data.response
			@size     = size = if res.headers['content-length']
				then parseInt res.headers['content-length']
				else 0
			# }}}
			@read = (chunkSize) ~> # {{{
				# check canceled
				if not stream
					return nullResolved
				# check read lock (repeated calls)
				if locked
					return locked
				# reset latency
				@latency = 0
				# check chunked
				if not chunk and chunkSize and chunkSize > 0
					chunk := new StreamChunk chunkSize
				# check buffered
				if buffer
					# determine amount
					if not (c = buffer.data.byteLength - buffer.dose)
						# dispose
						buffer := null
						# proceed to normal reading..
					else if chunk
						# chunk assembly
						# prepare
						a = chunk.dose
						b = chunk.data.byteLength - chunk.dose
						# check the inflation
						if c >= b
							# active buffer
							# get dose
							b = buffer.dose + b
							c = buffer.data.subarray buffer.dose, b
							buffer.dose = b
							# inject
							chunk.data.set c, a
							# complete chunk
							return locked := if pause
								then pause.then readBufComplete
								else nullResolved.then readBufComplete
						else
							# exhausted buffer
							# get what remains
							b = buffer.dose + c
							c = buffer.data.subarray buffer.dose, b
							# inject
							chunk.data.set c, a
							chunk.dose += c.byteLength
							# dispose
							buffer := null
							# continue reading
							return locked := if pause
								then pause.then readStart
								else readStart!
					else
						# no chunk but buffer remains!
						# eject the remains
						# into temporary chunk
						chunk := newStreamBuffer (buffer.data.slice buffer.dose), 0
						# dispose
						buffer := null
						# complete
						return locked := if pause
							then pause.then readBufComplete
							else nullResolved.then readBufComplete
				# start reading
				return locked := if pause
					then pause.then readStart
					else readStart!
			# }}}
			@pause = ~> # {{{
				# check canceled or paused
				if not stream or pause
					return false
				# set flag
				@paused = true
				# set promise
				a = null
				pause := new Promise (resolve) !->
					a := resolve
				# expose promise resolver
				pause.resolve = a
				return true
			# }}}
			@resume = ~> # {{{
				# check not paused
				if not pause
					return false
				# unpause
				pause.resolve!
				return true
			# }}}
			@cancel = ~> # {{{
				# check already canceled
				if not stream
					return false
				# cancel stream
				reader.cancel!
				reader.releaseLock!
				# dispose variables
				reader := stream := null
				# unpause
				pause.resolve! if pause
				# done
				return true
			# }}}
			# shorthands
			@readInt = ~>> # {{{
				# read 4 bytes
				if not a = await @read 4
					return null
				# check
				if a.byteLength != 4
					return null
				# convert big-endian sequence to integer
				return a.0 .<<. 24 .|. \
				       a.1 .<<. 16 .|. \
				       a.2 .<<.  8 .|. \
				       a.3
			# }}}
			@readString = ~>> # {{{
				# read size of the string
				if (a = await @readInt!) == null
					return null
				# read bytes
				if (a = await @read a) == null
					return null
				# decode as utf8
				return textDecode a
			# }}}
			@readJSON = ~>> # {{{
				# read string
				if (a = await @readString!) == null
					return null
				# parse
				try
					a = JSON.parse a
				catch
					a = new FetchError 1, 'incorrect JSON'
				# complete
				return a
			# }}}
		###
		return FetchStream
	# }}}
	FetchHandler = (config) !-> # {{{
		# create object shape
		@config  = config
		@api     = new Api @
		@store   = new Map!
		@fetch   = ~> # {{{
			# PREPARE
			# {{{
			# create base objects
			d = new FetchData config
			o = new FetchOptions!
			# parse arguments
			if config.mounted
				# mounted instance:
				# - no options
				# - result is handled with promise
				# - input parameter is data
				options   = {}
				d.promise = newPromise d
				if arguments.length
					options.data = data = arguments.0
				###
			else if (e = parseArguments arguments) instanceof Error
				# incorrect input:
				# - dummy options
				# - error is handled with promise
				# - no data
				options   = {}
				d.promise = newPromise d
			else
				# standard input
				# custom options
				options = e.0
				# custom result handling mode
				if e.1
					d.callback = e.1
				else
					d.promise = newPromise d
				# custom data
				if options.hasOwnProperty 'data'
					data = options.data
				# no error
				e = false
			# create request shorthand variable
			r = d.response.request
			# }}}
			# INITIALIZE
			# set request control options {{{
			# set url
			r.setUrl config.baseUrl, options.url
			# set timeout
			if options.hasOwnProperty 'timeout' and (a = options.timeout) >= 0
				d.timeout = 1000 * a
			# set redirect count
			if options.hasOwnProperty 'redirectCount'
				d.redirect.count = options.redirectCount .|. 0
			# set parsing mode
			if options.hasOwnProperty 'parseResponse'
				d.parseResponse = if typeof options.parseResponse == 'string'
					then options.parseResponse
					else ''
			# set flags
			for a in config.flagOptions when options.hasOwnProperty a
				d[a] = !!options[a]
			# set aborter
			d.aborter = if (a = options.aborter) and a instanceof AbortController
				then a
				else new AbortController!
			# set abort signal
			o.signal = d.aborter.signal
			# set native options
			for a in config.fetchOptions
				if options.hasOwnProperty a
					o[a] = options[a]
				else if config[a] != null
					o[a] = config[a]
			# set request method
			if options.hasOwnProperty 'method'
				o.method = options.method
			else if options.hasOwnProperty 'data'
				o.method = 'POST'
			# }}}
			# set headers and body {{{
			# store new headers reference into request
			r.headers = o.headers
			# merge config
			if config.headers
				o.setHeaders config.headers
			# merge user options
			if typeof! options.headers == 'Object'
				o.setHeaders options.headers
			# check data
			if data != undefined and not e
				# DATA!
				# prepare
				a = o.headers['content-type']
				b = typeof! data
				# check encryption enabled
				if c = config.secret
					# ENCRYPTED!
					# enforce proper encoding
					o.headers['content-encoding'] = 'aes256gcm'
					# advance counter and
					# set request counter tag
					o.headers['etag'] = c.next!tag!
					# check content-type
					switch 0
					case a.indexOf 'application/x-www-form-urlencoded'
						# TODO: Enforce JSON?
						o.headers['content-type'] = 'application/json'
						fallthrough
					case a.indexOf 'application/json'
						# JSON
						if b != 'String' and not (data = jsonEncode data)
							e = new FetchError 3, 'failed to encode request data to JSON'
					case a.indexOf 'multipart/form-data'
						# JSON in FormData
						# prepared data is not supported
						if b in <[String FormData]>
							e = new FetchError 3, 'encryption of prepared FormData is not supported'
						# remove type header
						delete o.headers['content-type']
						# the data will be wrapped after encryption!
						# TODO
						# ...
					default
						# RAW
						if b not in <[String ArrayBuffer]>
							e = new FetchError 3, 'incorrect request raw data type'
				else
					# NOT ENCRYPTED!
					# check content-type
					switch 0
					case a.indexOf 'application/json'
						# JSON
						if b != 'String' and not (data = jsonEncode data)
							e = new FetchError 3, 'failed to encode request data to JSON'
					case a.indexOf 'application/x-www-form-urlencoded'
						# URLSearchParams
						if b not in <[String URLSearchParams]> and not (data = newQueryString data)
							e = new FetchError 3, 'failed to encode request data to URLSearchParams'
					case a.indexOf 'multipart/form-data'
						# FormData
						if b not in <[String FormData]> and not (data = newFormData data)
							e = new FetchError 3, 'failed to encode request data to FormData'
						# remove type header, because it conflicts with FormData object,
						# despite it perfectly fits the logic (wtf)
						if b != 'String'
							delete o.headers['content-type']
					default
						# RAW
						if b not in <[String ArrayBuffer]>
							e = new FetchError 3, 'incorrect request raw data type'
				# set
				o.body = r.data = data
			else
				# NO DATA! NO BODY! NO HEAD!
				# remove content-type header
				delete o.headers['content-type']
			# }}}
			# check for instant FetchError {{{
			if e
				# fail fast, but not faster
				if d.callback
					d.callback false, e
					return d.aborter
				else
					d.promise.pending = false
					if d.promiseReject
						d.promise.reject e
					else
						d.promise.resolve e
					return d.promise
			# }}}
			# RUN
			# {{{
			if config.secret
				# start encryption
				e = config.secret.encrypt o.body, true
				# handle completion
				e.data.then (buf) !~>
					# set encrypted data
					o.body = e.data = buf
					r.crypto = data
					# check aborted
					if o.signal.aborted
						throw new FetchError 4, 'aborted programmatically'
					# invoke
					@handler d, o
				.catch (e) !~>
					# set encryption error
					if not (e.hasOwnProperty 'id')
						e = new FetchError 2, 'encryption failed: '+e.message
					# fail
					@fail d, e
			else
				# invoke
				@handler d, o
			# done
			return if d.callback
				then d.aborter
				else d.promise
			# }}}
		# }}}
		@handler = (data, options) !~> # {{{
			# prepare
			res = data.response
			sec = config.secret if data.parseResponse == 'data'
			# activate timer
			if data.timeout
				data.timer = setTimeout data.timerFunc, data.timeout
			# create handler routines
			responseHandler = (r) ~> # {{{
				# initialize the response
				res.time    = performance.now!
				res.status  = r.status
				res.type    = r.type
				res.headers = h = {}
				# terminate timeout timer
				if data.timer
					data.timerFunc true
				# collect headers
				a = r.headers.entries!
				while not (b = a.next!).done
					h[b.value.0.toLowerCase!] = b.value.1
				# check unsuccessful status range (not in 200-299)
				if not r.ok
					# check opaque
					if r.type == 'opaqueredirect'
						throw new FetchError 0, 'opaque redirect'
					# check redirection
					if r.status >= 300 and r.status <= 399
						# check location specified
						if not h.hasOwnProperty 'location'
							throw new FetchError 0, 'no redirect location'
						# check counter
						if not (a = data.redirect).count
							throw new FetchError 0, 'no more redirects allowed'
						# limit finite redirection (infinite when <0)
						if a.count > 0 and ++a.current > a.count
							throw new FetchError 0, 'too many redirects'
						# follow this redirect (retry)
						res.request.url = h.location
						@handler data, options
						throw null
						#throw new FetchError 3, 'not implemented yet'
					# fail
					# TODO: parse body as text if possible
					throw new FetchError 0, 'unsuccessful response status'
				# check HTTP status 200
				if r.status != 200 and data.status200
					throw new FetchError 0, 'HTTP status 200 required'
				# check opaque
				if r.type == 'opaque' and data.parseResponse
					throw new FetchError 1, 'unable to parse opaque response'
				# check parsing mode
				switch data.parseResponse
				case 'stream'
					# chunks of data
					return new FetchStream r.body, data, sec
				case 'data'
					# single chunk
					# encrypted request means encrypted response,
					# so the content is always handled as binary
					if sec
						return r.arrayBuffer!
					# check accepted content type
					b = h['content-type'] or ''
					if a = options.headers.accept
						# prefer own setting and
						# do a loose match against server's
						if b and (b.indexOf a) != 0
							throw new FetchError 1, 'incorrect content-type header'
					else
						# use server setting
						a = b
					# return parsed content
					switch 0
					case a.indexOf 'application/json'
						# JSON:
						# - not using .json, because response with empty body
						#   will throw error at no-cors opaque mode (who needs that?)
						# - the UTF-8 BOM, must not be added, but if present,
						#   will be stripped by .text
						return r.text!
							.then jsonDecode
					case a.indexOf 'application/octet-stream'
						# binary
						return r.arrayBuffer!
					case a.indexOf 'text/'
						# plaintext
						return r.text!
					case (a.indexOf 'image/'), \
							(a.indexOf 'audio/'), \
							(a.indexOf 'video/')
						# blob
						return r.blob!
					case a.indexOf 'multipart/form-data'
						# FormData
						return r.formData!
					default
						# assume binary
						return r.arrayBuffer!
				# as is, dont parse
				return r
			# }}}
			sec and decryptHandler = (buf) -> # {{{
				# check for empty response
				if buf.byteLength == 0
					return null
				# decrypt data
				a = sec.decrypt buf, res.request.crypto.params
				# handle completion
				return a.data.then (d) ->
					# check successful
					if d == null
						d = new FetchError 2, 'decryption failed'
						sec.manager 'fail', d
						throw d
					# store
					a.data = buf
					res.crypto = a
					# update secret
					sec.save!
					# parse content
					c = options.headers.accept or res.headers['content-type'] or ''
					switch 0
					case c.indexOf 'application/json'
						# Object
						c = jsonDecode d
					case c.indexOf 'text/'
						# String
						c = textDecode d
					default
						# Binary, as is
						c = d
					# done
					return c
			# }}}
			successHandler = (result) !~> # {{{
				@success data, result
			# }}}
			errorHandler = (error) !~> # {{{
				@fail data, error
			# }}}
			# set request time
			res.request.time = performance.now!
			# invoke the fetch api
			if decryptHandler
				fetch res.request.url, options
					.then responseHandler
					.then decryptHandler
					.then successHandler
					.catch errorHandler
			else
				fetch res.request.url, options
					.then responseHandler
					.then successHandler
					.catch errorHandler
			# store
			@store.set data, options
		# }}}
	# httpFetch instance identifier
	FetchHandler.prototype = {
		success: (data, result) !-> # {{{
			# unify nulls
			switch typeof! result
			case 'Blob'
				result = null if result.size == 0
			case 'ArrayBuffer'
				result = null if result.byteLength == 0
			# check nulls allowed
			if data.notNull and result == null
				throw new FetchError 1, 'response result is null'
			# set response result
			data.response.data = result
			# set full result
			if data.fullHouse and data.parseResponse == 'data'
				result = data.response
			# check mode
			if data.callback
				# callback
				a = data.callback true, result
				# check async
				if a instanceof Promise
					# get options
					options = @store.get data
					# enable request retries
					a.then (retry) !~>
						if retry
							@handler data, options
			else
				# resolve promise
				data.promise.pending = false
				data.promise.resolve result
			# cleanup
			@store.delete data
		# }}}
		fail: (data, error) !-> # {{{
			# internal retry (redirect)(?)
			if error == null
				return
			# get options and
			# check it's a cancellation
			if (options = @store.get data) and \
			   options.signal.aborted and \
			   not (error.hasOwnProperty 'id')
				###
				# determine cancellation type and
				# replace standard error
				error = if data.timeout and not data.timer
					then new FetchError 0, 'connection timed out'
					else new FetchError 4, error.message
			# after cancelation checked,
			# terminate timer
			if data.timer
				data.timerFunc true
			# wrap unhandled error into FetchError
			if not (error.hasOwnProperty 'id')
				error = new FetchError 5, error.message
			# attach the response
			error.response = data.response
			error.status = data.response.status
			# check mode
			if data.callback
				# callback
				a = data.callback false, error
				# check async
				if (a instanceof Promise) and options
					# enable request retries
					a.then (retry) !~>
						if retry
							@handler data, options
			else
				# resolve promise
				data.promise.pending = false
				if data.promiseReject
					data.promise.reject error
				else
					data.promise.resolve error
			# cleanup
			@store.delete data
		# }}}
	}
	# }}}
	Api = (handler) !-> # {{{
		###
		# new instance (fetchers group)
		@create = newInstance handler.config
		# group cancellation
		@cancel = -> # {{{
			# TODO
			return true
		# }}}
		# form enctypes request
		@form = -> # {{{
			# prepare
			if (a = parseArguments arguments) instanceof Error
				return handler.fetch a
			# get headers
			b = a.0
			c = if b.headers
				then b.headers
				else {}
			# determine proper content type
			if typeof b.data == 'object'
				c['content-type'] = if isFormData b.data
					then 'multipart/form-data'
					else 'application/x-www-form-urlencoded'
			else
				c['content-type'] = 'text/plain'
			# set headers
			a.0.headers = c
			# set proper method
			a.method = 'POST'
			# done
			return handler.fetch a.0, a.1
		# }}}
		###
		# Crypto
		if not apiCrypto
			return
		handshakeLocked = false
		@handshake = (url, storeManager) ~>> # {{{
			# Diffie-Hellman-Merkle key exchange
			# check lock
			if handshakeLocked
				return false
			# destroy current secret?
			if not storeManager
				if k = handler.config.secret
					handler.config.secret = null
					apiCrypto.secretManagersPool.delete k.manager
					k.manager 'destroy', ''
				# done
				return true
			# check unique
			if apiCrypto.secretManagersPool.has storeManager
				consoleError 'secret manager must be unique'
				return false
			# lock
			handshakeLocked := true
			# try to restore saved secret
			if k = storeManager 'get'
				k = handler.config.secret = await apiCrypto.newSecret k, storeManager
				handshakeLocked := false
				return !!k
			# create verification hashes:
			# H0, will be encrypted and sent to the server
			# H1, will be compared against hash produced by the server
			if not (hash = await apiCrypto.generateHashPair!)
				handshakeLocked := false
				return false
			# the cycle below is needed because of practical inaccuracies
			# found during the testing process. Their elimination is
			# avoided by re-starting of the process (which is simple).
			x = false
			c = 4
			while --c
				# STAGE 1: EXCHANGE
				# create own ECDH keys (private and public)
				if not (k = await apiCrypto.generateKeyPair!)
					break
				# initiate public key exchange
				b = {
					url: url
					method: 'POST'
					data: k.1
					headers: {
						'content-type': 'application/octet-stream'
						'etag': 'exchange'
					}
					fullHouse: false
					timeout: 0
				}
				a = await handler.fetch b
				# check the response
				if not a or (a instanceof Error)
					break
				# convert to CryptoKey
				if (a = await apiCrypto.importKey a) == null
					break
				# create shared secret key
				if (a = await apiCrypto.deriveKey k.0, a) == null
					break
				# create key storage
				if (k = await apiCrypto.newSecret a, storeManager) == null
					break
				# STAGE 2: VERIFY
				# encrypt first hash
				b.headers.etag = 'verify'
				if (b.data = await k.encrypt hash.0) == null
					break
				# send it
				a = await handler.fetch b
				# check the response
				if not a or not (a instanceof ArrayBuffer)
					break
				# check if decryption failed
				if (i = a.byteLength) != 0
					# compare against second hash
					a = new Uint8Array a
					if (b = hash.1).byteLength != i
						break
					while --i >= 0
						if a[i] != b[i]
							break
					if i == -1
						x = true # confirm!
						break
				# ..repeat the attempt!
			# store
			if x and handler.config.secret = k.save!
				apiCrypto.secretManagersPool.set k.manager
			# complete
			handshakeLocked := false
			return x
		# }}}
	# }}}
	ApiHandler = (handler) !-> # {{{
		@get = (f, k, p) -> # {{{
			# check property
			switch k
			case 'isGlobal'
				# only first instance is global
				return (p == httpFetch)
			case 'secret'
				return if a = handler.config.secret
					then a.get!
					else ''
			case 'prototype'
				# this special case must be handled
				# to make *instanceof* syntax working
				return FetchHandler.prototype
			default
				if handler.config.hasOwnProperty k
					return handler.config[k]
			# check method/interface
			if handler.api[k]
				return handler.api[k]
			# nothing
			return null
		# }}}
		@set = (f, k, v) -> # {{{
			# set property
			cfg = handler.config
			if cfg.hasOwnProperty k
				if k == 'baseUrl'
					# string
					if typeof v == 'string'
						cfg[k] = v
				else if (cfg.flagOptions.indexOf k) != -1
					# boolean
					cfg[k] = !!v
				else if 'timeout'
					# positive integer
					if (v = parseInt v) >= 0
						cfg[k] = v
			# done
			return true
		# }}}
	###
	ApiHandler.prototype = {
		setPrototypeOf: ->
			return false
		getPrototypeOf: ->
			return FetchHandler.prototype
	}
	# }}}
	# factories
	newFormData = do -> # {{{
		# prepare recursive helper function
		add = (data, item, key) ->
			# check type
			switch typeof! item
			case 'Object'
				# object's own properties are iterated
				# with the respect to definition order (top to bottom)
				b = Object.getOwnPropertyNames item
				if key
					for a in b
						add data, item[a], key+'['+a+']'
				else
					for a in b
						add data, item[a], a
			case 'Array'
				# the data parameter may be array itself,
				# in this case it is unfolded to a set of parameters,
				# otherwise, additional brackets are added to the name,
				# which is common (for example, to PHP parser)
				key = if key
					then key+'[]'
					else ''
				b = item.length
				a = -1
				while ++a < b
					add data, item[a], key
			case 'HTMLInputElement'
				# file inputs are unfolded to FileLists
				if item.type == 'file' and item.files.length
					add data, item.files, key
			case 'FileList'
				# similar to the Array
				if (b = item.length) == 1
					data.append key, item.0
				else
					a = -1
					while ++a < b
						data.append key+'[]', item[a]
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
	newQueryString = do -> # {{{
		# create recursive helper
		add = (list, item, key) ->
			# check item type
			switch typeof! item
			case 'Object'
				b = Object.getOwnPropertyNames item
				if key
					for a in b
						add list, item[a], key+'['+a+']'
				else
					for a in b
						add list, item[a], a
			case 'Array'
				key = if key
					then key+'[]'
					else ''
				b = item.length
				a = -1
				while ++a < b
					add list, item[a], key
			case 'Null'
				list[*] = (encodeURIComponent key)+'='
			default
				list[*] = (encodeURIComponent key)+'='+(encodeURIComponent item)
			# done
			return list
		# create simple factory
		return (o) ->
			return (add [], o, '').join '&'
	# }}}
	newPromise = (fetchData) -> # {{{
		# create standard promise and
		# store resolvers
		a = b = null
		p = new Promise (resolve, reject) !->
			a := resolve
			b := reject
		# customize standard object
		p.resolve = a
		p.reject  = b
		p.pending = true
		p.abort = p.cancel = !->
			if fetchData.aborter
				fetchData.aborter.abort!
		# done
		return p
	# }}}
	newInstance = (baseConfig) -> # {{{
		# mounted instances do not spawn children
		if baseConfig and baseConfig.mounted
			return null
		# create factory
		return (userConfig) ->
			# create new configuration
			config = new FetchConfig!
			# initialize it
			config.setOptions baseConfig if baseConfig
			config.setOptions userConfig if userConfig
			# create handlers
			a = new FetchHandler config
			b = new ApiHandler a
			# create custom instance
			return new Proxy a.fetch, b
	# }}}
	# create global instance and
	# keep it in its own scope
	return httpFetch = (newInstance null) null
###
# vim: ts=2 sw=2 sts=2 fdm=marker:
