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
	# constructors
	Config = !-> # {{{
		@baseUrl   = ''
		@status200 = true
		@fullHouse = false
		@notNull   = false
		@timeout   = 20
		@retry     = null
		@secret    = null
		@headers   = {
			'content-type': 'application/json; charset=utf-8'
		}
	Config.prototype = {
		set: do ->
			baseOptions = [
				'baseUrl'
				'status200'
				'fullHouse'
				'notNull'
				'timeout'
			]
			return (o) !->
				# set primitives
				for a in baseOptions when o.hasOwnProperty a
					@[a] = o[a]
				# set headers
				if o.headers
					@headers = {}
					for a,b of o.headers
						@headers[a.toLowerCase!] = b
				# done
	}
	# }}}
	RetryConfig = !-> # {{{
		@count        = 15
		@current      = 0
		@expoBackoff  = true
		@maxBackoff   = 32
		@delay        = 1
	# }}}
	ResponseData = do -> # {{{
		RequestData = !->
			@headers = null
			@data    = null
			@crypto  = null
		return ResponseData = !->
			@status  = 0
			@headers = null
			@data    = null
			@crypto  = null
			@request = new RequestData!
	# }}}
	FetchOptions = !-> # {{{
		@method      = 'GET'
		@headers     = {}
		@body        = null
		@mode        = 'cors'
		@credentials = 'include'
		@cache       = 'default'
		@redirect    = 'follow'
		@signal      = null
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
	FetchData = (config) !-> # {{{
		# result control
		@promise   = null
		@response  = new ResponseData!
		# cancellation control
		@aborter   = null
		@timer     = 0
		@timerFunc = !~>
			@timer = 0
			@aborter.abort!
		# connection control
		@retry     = new RetryConfig!
		# individual request configuration
		@status200 = config.status200
		@fullHouse = config.fullHouse
		@notNull   = config.notNull
		@timeout   = 1000 * config.timeout
	# }}}
	FetchHandler = (config) !-> # {{{
		handler = (url, options, data, callback) -> # {{{
			responseHandler = (r) -> # {{{
				# terminate timeout timer
				if data.timer
					clearTimeout data.timer
					data.timer = 0
				# check HTTP status
				# ok status is any status in the range 200-299,
				# modern API may limit it to 200 (this option is on by default)
				if not r.ok or (r.status != 200 and data.status200)
					throw new FetchError r.statusText, r.status
				# parse headers
				h = {}
				a = r.headers.entries!
				while not (b = a.next!).done
					h[b.value.0.toLowerCase!] = b.value.1
				# store
				data.response.status  = r.status
				data.response.headers = h
				# check encoding
				if (a = h['content-encoding']) == 'aes256gcm'
					# ENCRYPTED!
					# secret key must exist
					if not config.secret
						throw new FetchError 'unable to decrypt, no shared secret', r.status
					# encrypted content is always sent as binary
					return r.arrayBuffer!
				###
				# NOT ENCRYPTED!
				# determine content type (own setting is preferred)
				a = options.headers.accept or h['content-type'] or ''
				# parse content
				switch 0
				case a.indexOf 'application/json'
					# not using .json(), because response with empty body
					# will throw error at no-cors opaque mode (who needs that bullshit?)
					return r.text!.then jsonDecode
				case a.indexOf 'application/octet-stream'
					# binary data
					return r.arrayBuffer!
				default
					# plaintext
					return r.text!
			# }}}
			successHandler = (d) !->> # {{{
				# prepare
				res = data.response
				sec = config.secret
				# check if encryption enabled
				if sec
					# check if the response encrypted
					if d and res.headers['content-encoding'] == 'aes256gcm'
						# start decryption
						a = sec.decrypt d, res.request.crypto.params
						# wait completed
						if (b = await a.data) == null
							sec.manager 'error'
							throw new FetchError 'failed to decrypt the response', res.status
						# store original data
						a.data = d
						res.crypto = a
						# update secret
						sec.save!
						# determine content type (own setting is preferred)
						a = options.headers.accept or res.headers['content-type'] or ''
						# parse response
						switch 0
						case a.indexOf 'application/json'
							# Object
							d = jsonDecode b
						case a.indexOf 'text'
							# String
							d = textDecode b
						default
							# Binary
							d = b
					else
						# update secret anyway
						sec.save!
				# check for null (empty response)
				if d == null and data.notNull
					d = {}
				# prepare result
				if data.fullHouse
					res.data = d
				else
					res = d
				# return it through callback or promise
				if callback
					callback true, res
				else
					data.promise.pending = false
					data.promise.resolve res
			# }}}
			errorHandler = (e) !-> # {{{
				# return through callback or promise
				if callback
					callback false, e
				else
					data.promise.pending = false
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
			# call api
			return fetch url, options
				.then responseHandler
				.then successHandler
				.catch errorHandler
		# }}}
		# create object shape
		@config = config
		@api = new Api @
		@fetch = (options, callback) ->
			# PREPARE
			# {{{
			# check parameters
			if typeof! options != 'Object' or \
			   callback and typeof callback != 'function'
				###
				return new Error 'incorrect parameters'
			# create options and data
			o = new FetchOptions!
			d = new FetchData config
			# }}}
			# INITIALIZE
			# set individual option {{{
			if options.hasOwnProperty 'timeout' and (a = options.timeout) >= 0
				d.timeout = 1000 * a
			if options.hasOwnProperty 'status200'
				d.status200 = !!options.status200
			if options.hasOwnProperty 'fullHouse'
				d.fullHouse = !!options.fullHouse
			if options.hasOwnProperty 'notNull'
				d.notNull = !!options.notNull
			# }}}
			# set request method {{{
			if options.hasOwnProperty 'method'
				o.method = options.method
			else if options.data
				o.method = 'POST'
			# }}}
			# set request headers {{{
			# combine default headers with config and
			# put them into request
			d.response.request.headers = o.headers <<< config.headers
			# combine with options
			if a = options.headers
				for b of a
					o.headers[b.toLowerCase!] = a[b]
			# check encryption enabled
			if a = config.secret
				# enforce proper encoding
				o.headers['content-encoding'] = 'aes256gcm'
				# advance counter and
				# set request counter tag
				o.headers['etag'] = a.next!tag!
			# }}}
			# set request body {{{
			if c = options.data
				# prepare
				a = o.headers['content-type']
				b = typeof! c
				# check
				if config.secret
					# ENCRYPTED!
					switch 0
					case a.indexOf 'application/x-www-form-urlencoded'
						# Enforce JSON
						o.headers['content-type'] = 'application/json'
						fallthrough
					case a.indexOf 'application/json'
						# JSON
						if b != 'String' and not (c = jsonEncode c)
							return new Error 'failed to encode request data'
					case a.indexOf 'multipart/form-data'
						# TODO: JSON in FormData
						# prepared data is not supported
						if b in <[String FormData]>
							return new Error 'incorrect request data'
						# remove type header
						delete o.headers['content-type']
						# the data will be wrapped after encryption!
						# ...
					default
						# RAW
						if b not in <[String ArrayBuffer]>
							return new Error 'incorrect request data'
				else
					# NOT ENCRYPTED!
					switch 0
					case a.indexOf 'application/json'
						# JSON
						if b != 'String' and (c = jsonEncode c) == null
							return new Error 'failed to encode request data'
					case a.indexOf 'application/x-www-form-urlencoded'
						# URLSearchParams
						if b not in <[String URLSearchParams]> and not (c = newQueryString c)
							return new Error 'failed to encode request data'
					case a.indexOf 'multipart/form-data'
						# FormData
						if b not in <[String FormData]> and not (c = newFormData c)
							return new Error 'failed to encode request data'
						# remove type header, because it conflicts with FormData object,
						# despite it perfectly fits the logic (wtf)
						if b != 'String'
							delete o.headers['content-type']
					default
						# RAW
						if b not in <[String ArrayBuffer]>
							return new Error 'incorrect request data'
				# set
				o.body = d.response.request.data = c
			# }}}
			# set request controllers {{{
			# create aborter
			d.aborter = if options.aborter
				then options.aborter
				else new AbortController!
			# set abort signal
			o.signal = d.aborter.signal
			# TODO: set retry
			# {{{
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
			# }}}
			# create custom promise
			if not callback
				d.promise = newPromise d.aborter
			# }}}
			# RUN HANDLER
			# determine request url
			a = if options.url
				then config.baseUrl + options.url
				else config.baseUrl
			# check secret
			if b = config.secret
				# start request encryption
				c = b.encrypt o.body, true
				# wait completed
				c.data.then (e) !->
					# sucess
					# set encrypted data
					o.body = c.data = e
					d.response.request.crypto = c
					# invoke handler
					if not o.signal.aborted
						handler a, o, d, callback
				.catch (e) !->
					# failure
					if callback
						callback false, e
					else
						d.promise.pending = false
						d.promise.resolve e
			else
				# invoke handler
				handler a, o, d, callback
			# done
			return if callback
				then d.aborter
				else d.promise
	# }}}
	Api = (handler) !-> # {{{
		###
		# instance constructor
		@create = newInstance handler.config
		###
		# method shortcuts
		@post = (url, data, callback) -> # {{{
			o = {
				url: url
				method: 'POST'
				data: if data
					then data
					else ''
			}
			return handler.fetch o, callback
		# }}}
		@get = (url, callback) -> # {{{
			o = {
				url: url
				method: 'GET'
				data: ''
			}
			return handler.fetch o, callback
		# }}}
		###
		# cryptography section
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
				case 'baseURL'
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
		# create standard promise and take out its resolver routine
		a = null
		b = new Promise (resolve) !->
			a := resolve
		# customize standard promise object
		b.pending = true
		b.resolve = a
		b.controller = aborter
		b.abort = b.cancel = !-> aborter.abort!
		# done
		return b
	# }}}
	newInstance = (baseConfig) -> (userConfig) -> # {{{
		# create new configuration
		config = new Config!
		# initialize it
		config.set baseConfig if baseConfig
		config.set userConfig if userConfig
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
