"use strict"

soFetch = null
assert  = null
window.addEventListener 'load', !->>
	# prepare
	# {{{
	# check location and select a server
	isLocal = (window.location.href.indexOf 'local') != -1
	server = if isLocal
		then 'http://localhost'
		else 'http://46.4.19.13:30980'
	# create custom instance
	soFetch := httpFetch.create {
		baseUrl: server + '/api/http-fetch'
		timeout: 0
	}
	# check
	if not isLocal
		# check remote
		console.log 'httpFetch: remote version is '+(await soFetch '')
		if (await soFetch '/tests') != true
			soFetch := null
			console.log 'httpFetch: test interface is disabled'
			return
		# check local
		if not window.test
			console.log 'httpFetch: test function is not defined'
			return
	# }}}
	# create helpers
	# {{{
	window.assert = (title, expect) ->
		title = '%c'+title
		(res) !->
			###
			if res instanceof Error
				if res.hasOwnProperty 'id'
					res = 'FetchError('+res.id+')['+res.status+']: %c'+res.message+' ';
				else
					res = 'Error: %c'+res.message;
				expect := !expect
			else
				res = 'success(%c'+res+')';
			###
			expect := if expect
				then 'color:green'
				else 'color:red'
			###
			font = 'font-weight:bold;'
			console.log title+'%c'+res, font, font+expect, expect
	window.help = {
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
		bufToHex: do -> # {{{
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
	};
	window.sleep = (time) ->
		done = null
		setTimeout !->
			done!
		, time
		return new Promise (resolve) !->
			done := resolve
	# }}}
	# set source code
	if a = document.querySelector 'code.javascript'
		a.innerHTML = test.toString!
	# highlight it
	hljs.initHighlighting!
	# run test
	test!

