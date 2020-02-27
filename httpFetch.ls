'use strict'
httpFetch = do ->
	# check requirements
	# {{{
	api = [
		typeof fetch
		typeof AbortController
		typeof Proxy
		typeof Promise
		typeof WeakMap
		typeof TextDecoder
	]
	if api.includes 'undefined'
		console.log 'httpFetch: missing requirements'
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
				throw new FetchError 'incorrect JSON: '+s, 0
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
			console.log 'httpFetch: Web Crypto API is not available'
			return null
		# helplers
		CS = crypto.subtle
		nullFunc = -> null
		bufToHex = do -> # {{{
			# create convertion array
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
			return new Error 'no parameters'
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
				return new Error 'wrong url type'
			# check callback
			if a.1 and (typeof a.1 != 'function')
				return new Error 'wrong callback type'
		default
			# Incorrect syntax
			return new Error 'incorrect arguments syntax'
		# done
		return a
	# }}}
	# constructors
	FetchConfig = !-> # {{{
		@baseUrl        = ''
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
		@fullHouse      = false
		@notNull        = false
		@promiseReject  = false
		@timeout        = 20
		@retry          = null
		@secret         = null
		@headers        = null
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
		]
		flagOptions: [
			'status200'
			'fullHouse'
			'notNull'
			'promiseReject'
		]
		setOptions: (o) !->
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
				@headers = {}
				for a,b of o.headers
					@headers[a.toLowerCase!] = b
	}
	# }}}
	FetchOptions = !-> # {{{
		@method         = 'GET'
		@headers        = {'content-type': 'application/json;charset=utf-8'}
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
	FetchData = do -> # {{{
		ResponseData = do ->
			RequestData = !->
				@headers = null
				@data    = null
				@crypto  = null
			return ResponseData = !->
				@status  = 0
				@type    = null
				@headers = null
				@data    = null
				@crypto  = null
				@request = new RequestData!
		RetryData = !->
			@count        = 15
			@current      = 0
			@expoBackoff  = true
			@maxBackoff   = 32
			@delay        = 1
		###
		return FetchData = (config) !->
			# controllers and data
			@promise   = null
			@response  = new ResponseData!
			@retry     = new RetryData!
			@aborter   = null
			@timer     = 0
			@timerFunc = !~>
				@timer = 0
				@aborter.abort!
			# cumulative request configuration
			@status200     = config.status200
			@fullHouse     = config.fullHouse
			@notNull       = config.notNull
			@promiseReject = config.promiseReject
			@timeout       = 1000 * config.timeout
	# }}}
	FetchHandler = (config) !-> # {{{
		handler = (url, options, data, callback) !-> # {{{
			# prepare
			res = data.response
			sec = config.secret
			responseHandler = (r) -> # {{{
				# terminate timer
				if data.timer
					clearTimeout data.timer
					data.timer = 0
				# check HTTP status
				# ok status is any status in the range 200-299,
				# modern API may limit it to 200 (this option is on by default)
				if not r.ok or (r.status != 200 and data.status200)
					throw new FetchError r.statusText, r.status
				# set status
				res.status = r.status
				# set headers
				res.headers = h = {}
				a = r.headers.entries!
				while not (b = a.next!).done
					h[b.value.0.toLowerCase!] = b.value.1
				# set type and
				# check opaque
				if (res.type = r.type) == 'opaque'
					# check encrypted
					if sec
						# can't access data === can't decrypt it
						throw new FetchError 'encrypted opaque response', r.status
					# return as is,
					# the opaque Response object may be consumed by other APIs
					return r
				# encrypted request enforce encrypted response and
				# content is handled as binary..
				if sec
					return r.arrayBuffer!
				###
				# determine content type (own setting is preferred)
				a = options.headers.accept or h['content-type'] or ''
				# parse content
				switch 0
				case a.indexOf 'application/json'
					# JSON:
					# - not using .json, because response with empty body
					#   will throw error at no-cors opaque mode (who needs that?)
					# - the UTF-8 BOM, must not be added, but if present,
					#   will be stripped by .text
					return r.text!then jsonDecode
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
			# }}}
			sec and decryptHandler = (buf) -> # {{{
				# check for empty response
				if buf.byteLength == 0
					return null
				# start decryption
				a = sec.decrypt buf, res.request.crypto.params
				# wait
				return a.data.then (d) ->
					# check decrypted data
					if (a.data = d) == null
						sec.manager 'fail'
						throw new FetchError 'failed to decrypt', res.status
					# store
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
			successHandler = (d) !-> # {{{
				# check for empty response
				if data.notNull and \
				   ((a = typeof! d) == 'Null' or \
				    a == 'Blob' and a.size == 0 or \
				    a == 'ArrayBuffer' and a.byteLength == 0)
					###
					throw new FetchError 'empty response', res.status
				# prepare result
				if data.fullHouse
					res.data = d
					d = res
				# return it through callback or promise
				if callback
					callback true, d
				else
					data.promise.pending = false
					data.promise.resolve d
			# }}}
			errorHandler = (e) !-> # {{{
				# terminate timer
				if data.timer
					clearTimeout data.timer
					data.timer = 0
				else if data.timeout and options.signal.aborted
					# replace aborter Error with
					# connection timeout Error
					e = new FetchError 'connection timed out', 0
				# return through callback or promise
				if callback
					callback false, e
				else
					data.promise.pending = false
					if data.promiseReject
						data.promise.reject e
					else
						data.promise.resolve e
				/***
				# TODO: retry request?!
				while true
					# check for incorrect response
					if not (e instanceof FetchError) or e.status == 0
						break
					# check limit
					if not (a = data.retry).count or a.current < a.count
						break
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
					# activate re-try
					setTimeout handlerFunc, b
					return
				/***/
			# }}}
			# set timer
			if data.timeout
				data.timer = setTimeout data.timerFunc, data.timeout
			# invoke the Fetch API
			if sec
				fetch url, options
					.then responseHandler
					.then decryptHandler
					.then successHandler
					.catch errorHandler
			else
				fetch url, options
					.then responseHandler
					.then successHandler
					.catch errorHandler
		# }}}
		# create object shape
		@config = config
		@api    = new Api @
		@fetch  = ->
			# PREPARE BASE
			# {{{
			# create important objects
			o = new FetchOptions!
			d = new FetchData config
			# parse arguments
			if (e = parseArguments arguments) instanceof Error
				# set dummy values
				options  = {}
				callback = false
			else
				# extract values
				options  = e.0
				callback = e.1
				# no error
				e = false
			# get url
			url = if options.hasOwnProperty 'url'
				then config.baseUrl + options.url
				else config.baseUrl
			# get data
			if options.hasOwnProperty 'data'
				data = options.data
			# }}}
			# INITIALIZE
			# individual options {{{
			# set timeout
			if options.hasOwnProperty 'timeout' and (a = options.timeout) >= 0
				d.timeout = 1000 * a
			# set flags
			for a in config.flagOptions when options.hasOwnProperty a
				d[a] = !!options[a]
			# set native
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
			# request headers and body {{{
			# combine default headers with config and
			# put them into request
			o.headers <<< config.headers if config.headers
			d.response.request.headers = o.headers
			# combine with options
			if a = options.headers
				for b of a
					o.headers[b.toLowerCase!] = a[b]
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
							e = new Error 'failed to encode request data'
					case a.indexOf 'multipart/form-data'
						# TODO: JSON in FormData
						# prepared data is not supported
						if b in <[String FormData]>
							e = new Error 'incorrect request data'
						# remove type header
						delete o.headers['content-type']
						# the data will be wrapped after encryption!
						# ...
						# ...
						# ...
					default
						# RAW
						if b not in <[String ArrayBuffer]>
							e = new Error 'incorrect data type'
				else
					# NOT ENCRYPTED!
					# check content-type
					switch 0
					case a.indexOf 'application/json'
						# JSON
						if b != 'String' and not (data = jsonEncode data)
							e = new Error 'failed to encode request data'
					case a.indexOf 'application/x-www-form-urlencoded'
						# URLSearchParams
						if b not in <[String URLSearchParams]> and not (data = newQueryString data)
							e = new Error 'failed to encode request data'
					case a.indexOf 'multipart/form-data'
						# FormData
						if b not in <[String FormData]> and not (data = newFormData data)
							e = new Error 'failed to encode request data'
						# remove type header, because it conflicts with FormData object,
						# despite it perfectly fits the logic (wtf)
						if b != 'String'
							delete o.headers['content-type']
					default
						# RAW
						if b not in <[String ArrayBuffer]>
							e = new Error 'incorrect data type'
				# set
				o.body = d.response.request.data = data
			else
				# NO DATA! NO BODY! NO HEAD!
				# remove content-type header
				delete o.headers['content-type']
			# }}}
			# request controllers {{{
			# set aborter
			d.aborter = if (a = options.aborter) and a instanceof AbortController
				then a
				else new AbortController!
			# set abort signal
			o.signal = d.aborter.signal
			# set promise
			if not callback
				d.promise = newPromise d.aborter
			/*** TODO: set retry
			# copy configuration
			a = d.retry
			if b = config.retry
				for c of a
					a[c] = b[c]
			# copy user options
			if b = options.retry
				if typeof! b == 'Object'
					for c of a when b.hasOwnProperty c
						a[c] = b[c]
				else
					a.count = b
			# fix values
			a.current = 0
			a.maxBackoff = 1000 * a.maxBackoff
			/***/
			# }}}
			# check for instant error {{{
			if e
				# fail fast, but not faster
				if callback
					callback false, e
					return d.aborter
				else
					d.promise.pending = false
					if d.promiseReject
						d.promise.reject e
					else
						d.promise.resolve e
					return d.promise
			# }}}
			# RUN HANDLER
			# check secret
			if config.secret
				# start encryption
				data = config.secret.encrypt o.body, true
				# handle completion
				data.data.then (e) !->
					# successfully encrypted
					# store properly
					o.body = data.data = e
					d.response.request.crypto = data
					# check aborted
					if o.signal.aborted
						throw new Error 'aborted programmatically'
					# invoke handler
					handler url, o, d, callback
				.catch (e) !->
					# failed to encrypt
					if callback
						callback false, e
					else
						d.promise.pending = false
						if d.promiseReject
							d.promise.reject e
						else
							d.promise.resolve e
			else
				# invoke handler
				handler url, o, d, callback
			# done
			return if callback
				then d.aborter
				else d.promise
	###
	FetchHandler.prototype = {} # global identifier
	# }}}
	Api = (handler) !-> # {{{
		###
		# instance parent
		@create = newInstance handler.config
		###
		# content-type shortcuts
		@json = -> # {{{
			# prepare
			if (a = parseArguments arguments) instanceof Error
				return handler.fetch a
			# set proper headers
			b = {'content-type': 'application/json;charset=utf-8'}
			if a.0.headers
				a.0.headers <<< b
			else
				a.0.headers = b
			# done
			return handler.fetch a.0, a.1
		# }}}
		@text = -> # {{{
			# prepare
			if (a = parseArguments arguments) instanceof Error
				return handler.fetch a
			# set proper headers
			b = {'content-type': 'text/plain;charset=utf-8'}
			if a.0.headers
				a.0.headers <<< b
			else
				a.0.headers = b
			# done
			return handler.fetch a.0, a.1
		# }}}
		###
		# crypto section
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
				console.log 'httpFetch: secret manager must be unique'
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
		@get = (f, key) -> # {{{
			# check property
			switch key
			case 'secret'
				return !!handler.config.secret
			case 'prototype'
				# to make *instanceof* syntax working,
				# this special name must be handled
				return FetchHandler.prototype
			default
				if handler.config.hasOwnProperty key
					return handler.config[key]
			# check method/interface
			if handler.api[key]
				return handler.api[key]
			# nothing
			return null
		# }}}
		@set = (f, key, val) -> # {{{
			# set property
			if handler.config.hasOwnProperty key
				switch key
				case 'baseUrl'
					# string
					if typeof val == 'string'
						handler.config[key] = val
				case 'status200', 'notNull', 'fullHouse'
					# boolean
					handler.config[key] = !!val
				case 'timeout'
					# positive integer
					if (val = parseInt val) >= 0
						handler.config[key] = val
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
	newPromise = (aborter) -> # {{{
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
		p.controller = aborter
		p.abort = p.cancel = !-> aborter.abort!
		# done
		return p
	# }}}
	newInstance = (baseConfig) -> (userConfig) -> # {{{
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
	# create global instance
	return (newInstance null) null
###
if httpFetch and typeof module != 'undefined'
	module.exports = httpFetch

# vim: ts=2 sw=2 sts=2 fdm=marker:
