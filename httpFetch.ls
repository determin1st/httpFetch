'use strict'
httpFetch = do ->
	# check requirements
	# {{{
	api = [
		typeof fetch
		typeof AbortController
		typeof Proxy
		typeof Promise
	]
	if api.includes 'undefined'
		console.log 'httpFetch: missing requirements'
		return null
	# }}}
	# initialize
	Config = !-> # {{{
		@baseUrl   = ''
		@status200 = true
		@fullSet   = false
		@noEmpty   = false
		@timeout   = 20
		@retry     = null
		@secret    = null
		@headers   = {
			'accept': 'application/json'
			'content-type': 'application/json; charset=utf-8'
		}
	# }}}
	RetryConfig = !-> # {{{
		@count        = 15
		@current      = 0
		@expoBackoff  = true
		@maxBackoff   = 32
		@delay        = 1
	# }}}
	ResponseData = !-> # {{{
		@headers = null
		@data    = null
	# }}}
	FetchOptions = (method) !-> # {{{
		@method  = method
		@body    = null
		@signal  = null
		@headers = {}
		@mode    = 'cors'
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
	FetchHandlerData = !-> # {{{
		# create object shape
		# properties
		@aborter  = null
		@timeout  = 0
		@timer    = 0
		@retry    = new RetryConfig!
		@promise  = null
		@response = new ResponseData!
		# bound methods
		@timerFunc = !~>
			@aborter.abort!
			@timer = 0
	# }}}
	FetchHandler = (config) !-> # {{{
		# prepare helpers
		jsonParser = (r) -> # {{{
			# parse non-empty as a JSON
			if r
				try
					return JSON.parse r
				catch e
					throw new FetchError 'Incorrect response: '+r, 0
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
			responseHandler = (r) -> # {{{
				# check for HTTP status
				if not r.ok or (r.status != 200 and config.status200)
					throw new FetchError r.statusText, r.status
				# parse response headers
				h = {}
				a = r.headers.entries!
				while not (b = a.next!).done
					h[b.value.0.toLowerCase!] = b.value.1
				# store them
				if options.fullSet
					data.response.headers = h
				# determine content type (server setting is preffered)
				a = if h['content-type']
					then h['content-type']
					else options.headers.accept
				# parse content
				switch 0
				case a.indexOf 'application/json'
					# not using .json(), because response with empty body
					# will throw error at no-cors opaque mode (who needs that bullshit?)
					return r.text!.then jsonParser
				case a.indexOf 'application/octet-stream'
					# binary data
					return r.arrayBuffer!.then (r) ->
						# TODO
						# check encrypted with shared secret
						if h['content-encoding'] == 'aes256gcm' and config.secret
							# decrypt
							# ...
							#crypto.subtle.decrypt aesParams, s, b
							true
						# done
						return r
				default
					# assume simpliest, text/plain
					return r.text!
			# }}}
			successHandler = (r) !-> # {{{
				# stop timer
				if data.timer
					clearTimeout data.timer
					data.timer = 0
				# compose resulting dataset if required
				if options.fullSet
					data.response.data = r
					r = data.response
				# return result through callback or promise object
				if callback
					callback true, r
				else
					data.promise.pending = false
					data.promise.resolve r
				# done
			# }}}
			errorHandler = (e) !-> # {{{
				# stop timer
				if data.timer
					clearTimeout data.timer
					data.timer = 0
				# run callback
				if callback and not callback false, e
					return
				# retry?
				# TODO: revise and test
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
				# check promise
				if not callback
					data.promise.pending = false
					data.promise.resolve e
				# complete
			# }}}
			return handlerFunc = !->
				# set timer
				if data.timeout
					data.timer = setTimeout data.timerFunc, data.timeout
				# call native fetch API
				fetch url, options
					.then responseHandler
					.then successHandler
					.catch errorHandler
		# }}}
		# create object shape
		@config = config
		@api = new Api @
		@fetch = (options, callback) ->
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
			d = new FetchHandlerData!
			# initialize
			# set headers
			o.headers <<< config.headers
			if a = options.headers
				for b of a
					o.headers[b.toLowerCase!] = a[b]
			# set request data
			# {{{
			if options.data
				# check content type
				a = o.headers['content-type']
				switch 0
				case a.indexOf 'application/json'
					# JSON
					o.body = if typeof options.data == 'string'
						then options.data
						else JSON.stringify options.data
				case a.indexOf 'multipart/form-data'
					# FormData
					o.body = if typeof! options.data == 'FormData'
						then options.data
						else newFormData options.data
					# remove type header,
					# as it conflicts with FormData object body,
					# despite they are equal (wtf)
					delete o.headers['content-type']
				default
					# AS IS
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
			# set promise
			if not callback
				d.promise = newPromise d.aborter
			# determine request url
			a = if options.url
				then config.baseUrl+options.url
				else config.baseUrl
			# run
			(handler a, o, d, callback)!
			# done
			return if callback
				then d.aborter
				else d.promise
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
		for c in [baseConfig, userConfig] when c
			# copy primitives (set complex)
			for a of config when c.hasOwnProperty a
				config[a] = c[a]
			# copy retry
			if c.retry
				config.retry = (new RetryConfig!) <<< c.retry
			# copy headers
			if c.headers
				config.headers = {}
				for a,b of c.headers
					config.headers[a.toLowerCase!] = b
		# create handlers
		a = new FetchHandler config
		b = new ApiHandler a
		# create httpFetch instance
		return new Proxy a.fetch, b
	# }}}
	apiCrypto = do -> # {{{
		# check requirements
		if (typeof crypto == 'undefined') or not crypto.subtle
			console.log 'httpFetch: Crypto API is not supported'
			return null
		# create singleton
		return {
			keyParams: {
				name: 'ECDH'
				namedCurve: 'P-521'
			}
			deriveParams: {
				name: 'HMAC'
				hash: 'SHA-512'
				length: 528
			}
			nullFunc: -> null
			generateKeyPair: ->> # {{{
				# create keys
				k = await (crypto.subtle.generateKey @keyParams, true, ['deriveKey'])
					.catch @nullFunc
				# check
				if k == null
					return null
				# convert public CryptoKey
				a = await (crypto.subtle.exportKey 'spki', k.publicKey)
					.catch @nullFunc
				# check
				if a == null
					return null
				# complete
				return {
					privateKey: k.privateKey
					publicKey: a
				}
			# }}}
			generateHashPair: ->> # {{{
				# create first hash
				a = await (crypto.subtle.generateKey @deriveParams, true, ['sign'])
					.catch @nullFunc
				# check
				return null if a == null
				# convert CryptoKey
				a = await (crypto.subtle.exportKey 'raw', a)
					.catch @nullFunc
				# check
				return null if a == null
				# create second hash
				b = await (crypto.subtle.digest 'SHA-512', a)
					.catch @nullFunc
				# check
				return null if b == null
				# done
				a = new Uint8Array a
				b = new Uint8Array b
				return [a, b]
				# convert binary to string,
				# this will produce same key as in JWK
				#return @bufToBase64 a
			# }}}
			importKey: (k) -> # {{{
				return (crypto.subtle.importKey 'spki', k, @keyParams, true, [])
					.catch @nullFunc
			# }}}
			deriveKey: (privateKey, publicKey) -> # {{{
				return (crypto.subtle.deriveKey {
					name: 'ECDH'
					public: publicKey
				}, privateKey, @deriveParams, true, ['sign'])
					.catch @nullFunc
			# }}}
			bufToHex: do -> # {{{
				# create convertion array
				hex = []
				i = -1
				n = 255
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
			bufToBn: (buf) -> # {{{
				# prepare
				hex = []
				u8  = Uint8Array.from buf
				c   = u8.length
				i   = -1
				# convert buffer to hex string
				while ++i < c
					h = u8[i].toString 16
					h = '0'+h if h.length % 2
					hex[i] = h
				# construct BigInt
				return BigInt '0x' + (hex.join '')
			# }}}
			bnToBuf: (bn, size = 0) -> # {{{
				# convert BigInt to hex string
				hex = BigInt bn .toString 16
				hex = '0' + hex if hex.length % 2
				len = hex.length / 2
				# determine padding size
				if not size
					size = len
				if (pad = size - len) < 0
					hex = hex.slice (-pad * 2)
					pad = 0
				# create buffer (assume, initialized with zeroes)
				u8 = new Uint8Array size
				# prepare
				i = pad
				j = i * 2
				# convert hex to integer value and
				# put it inside buffer
				while i < size
					u8[i] = parseInt (hex.slice j, j+2), 16
					i += 1
					j += 2
				# done
				return u8
			# }}}
			newSecret: do -> # {{{
				# helpers and constructors
				CipherParams = (iv) !->
					@name      = 'AES-GCM'
					@iv        = iv
					@tagLength = 128
				SecretStorage = (manager, key, iv, current, next) !->
					@manager = manager
					@key     = key
					@params  = new CipherParams iv
					@current = current
					@next    = next
				SecretStorage.prototype = {
					nullFunc: -> null
					stringToBuf: TextEncoder.prototype.encode.bind (new TextEncoder!)
					bufToString: TextDecoder.prototype.decode.bind (new TextDecoder 'utf-8')
					encrypt: (data) ->
						# convert data to ArrayBuffer
						if typeof data == 'string'
							data = @stringToBuf data
						# do it
						return (crypto.subtle.encrypt @params, @key, data)
							.catch @nullFunc
					decrypt: (data) ->
						# ...
						return (crypto.subtle.decrypt @params, @key, data)
							.catch @nullFunc
				}
				# factory
				return (ecdh_secret, manager) ->>
					# check
					if not ecdh_secret or ecdh_secret.length < 44
						return null
					# truncate secret
					ecdh_secret = ecdh_secret.slice 0, 44
					# extract key parts
					# there is no reason to apply more complex key "compression" functions,
					# because resistance of key preimages/collision wont improve..
					s = ecdh_secret.slice  0, 32    # 256bits (cipher key)
					c = ecdh_secret.slice 32, 32+12 # 96bit (counter/iv)
					# create new CryptoKey
					k = await (crypto.subtle.importKey 'raw', s, {name: 'AES-GCM'}, false, [
						'encrypt'
						'decrypt'
					]).catch @nullFunc
					# check
					if k == null
						return null
					# determine next secret (with increased counter)
					# split counter into two parts
					# this eleminates the chance of iv/counter becoming zero
					c1 = @bufToBn (c.slice 0, 6)
					c2 = @bufToBn (c.slice 6, 12)
					# increase each
					++c1
					++c2
					# convert BigInts back to buffers
					c1 = @bnToBuf c1, 6
					c2 = @bnToBuf c2, 6
					# concatenate them
					n = new Uint8Array 32+12
					n.set  s, 0
					n.set c1, 32
					n.set c2, 32+6
					# create storage
					return new SecretStorage manager, k, c, (@bufToBase64 ecdh_secret), (@bufToBase64 n)
			# }}}
		}
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
			# checkout current state
			if handshakeLocked
				return false
			handshakeLocked := true
			# checkout shared secret
			if a = storeManager!
				# already established,
				# convert it from base64
				a = apiCrypto.base64ToBuf a
				# create new storage
				if (k = await apiCrypto.newSecret a, storeManager) == null
					return false
				# done
				handler.config.secret = k
				handshakeLocked := false
				return true
			# let's create verification hashes:
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
					data: k.publicKey
					headers: {
						'accept': 'application/octet-stream'
						'content-type': 'application/octet-stream'
						'content-encoding': ''
					}
					timeout: 0
				}
				a = await handler.fetch b
				# check the response
				if not a or (a instanceof Error)
					break
				# convert to a CryptoKey
				if (a = await apiCrypto.importKey a) == null
					break
				# create shared secret key
				if (a = await apiCrypto.deriveKey k.privateKey, a) == null
					break
				# convert object to raw data
				a = await crypto.subtle.exportKey 'raw', a
				a = new Uint8Array a
				# trim leading zero-byte (!?)
				a = a.slice 1 if a.0 == 0
				# create key storage
				if (k = await apiCrypto.newSecret a, storeManager) == null
					break
				# STAGE 2: VERIFY
				# encrypt first hash
				b.headers['content-encoding'] = 'aes256gcm'
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
			# update configuration
			if x
				handler.config.secret = k
				storeManager k.current
			# done
			handshakeLocked := false
			return x
		# }}}
	# }}}
	ApiHandler = (handler) !-> # {{{
		@get = (f, key) -> # {{{
			# check method/interface
			if handler.api[key]
				return handler.api[key]
			# check property
			if handler.config.hasOwnProperty key
				return handler.config[key]
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
				case 'status200', 'noEmpty', 'fullSet'
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
	# create global instance
	return (newInstance null) null
###
if httpFetch and typeof module != 'undefined'
	module.exports = httpFetch

# vim: ts=2 sw=2 sts=2 fdm=marker:
