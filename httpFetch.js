// Generated by LiveScript 1.6.0
'use strict';
var httpFetch, toString$ = {}.toString;
httpFetch = function(){
  var api, jsonDecode, jsonEncode, textDecode, textEncode, apiCrypto, Config, RetryConfig, ResponseData, FetchOptions, FetchError, FetchData, FetchHandler, Api, ApiHandler, newFormData, newQueryString, newPromise, newInstance;
  api = [typeof fetch, typeof AbortController, typeof Proxy, typeof Promise, typeof WeakMap, typeof TextDecoder];
  if (api.includes('undefined')) {
    console.log('httpFetch: missing requirements');
    return null;
  }
  jsonDecode = function(s){
    var e;
    if (s) {
      try {
        return JSON.parse(s);
      } catch (e$) {
        e = e$;
        throw new FetchError('incorrect JSON: ' + s, 0);
      }
    }
    return null;
  };
  jsonEncode = function(o){
    try {
      return JSON.stringify(o);
    } catch (e$) {
      e$;
      return null;
    }
  };
  textDecode = function(){
    var t;
    t = new TextDecoder('utf-8');
    return function(buf){
      return t.decode(buf);
    };
  }();
  textEncode = function(){
    var t;
    t = new TextEncoder();
    return function(str){
      return t.encode(str);
    };
  }();
  apiCrypto = function(){
    var CS, nullFunc, bufToHex, hexToBuf, bufToBigInt, bigIntToBuf;
    if (typeof crypto === 'undefined' || !crypto.subtle) {
      console.log('httpFetch: Web Crypto API is not available');
      return null;
    }
    CS = crypto.subtle;
    nullFunc = function(){
      return null;
    };
    bufToHex = function(){
      var hex, i, n;
      hex = [];
      i = -1;
      n = 256;
      while (++i < n) {
        hex[i] = i.toString(16).padStart(2, '0');
      }
      return function(buf){
        var a, b, i, n;
        a = new Uint8Array(buf);
        b = [];
        i = -1;
        n = a.length;
        while (++i < n) {
          b[i] = hex[a[i]];
        }
        return b.join('');
      };
    }();
    hexToBuf = function(hex){
      var len, buf, i, j;
      if ((len = hex.length) % 2) {
        hex = '0' + hex;
        ++len;
      }
      len = len / 2;
      buf = new Uint8Array(len);
      i = -1;
      j = 0;
      while (++i < len) {
        buf[i] = parseInt(hex.slice(j, j + 2), 16);
        j += 2;
      }
      return buf;
    };
    bufToBigInt = function(buf){
      return BigInt('0x' + bufToHex(buf));
    };
    bigIntToBuf = function(bi, size){
      var buf, len, big;
      buf = hexToBuf(bi.toString(16));
      if (!size || (len = buf.length) === size) {
        return buf;
      }
      if (len > size) {
        buf = buf.slice(len - size);
      } else {
        big = new Uint8Array(size);
        big.set(buf, size - len);
        buf = big;
      }
      return buf;
    };
    return {
      cs: CS,
      secretManagersPool: new WeakMap(),
      keyParams: {
        name: 'ECDH',
        namedCurve: 'P-521'
      },
      derivePublicKey: {
        name: 'HMAC',
        hash: 'SHA-512',
        length: 528
      },
      deriveParams: {
        name: 'HMAC',
        hash: 'SHA-512',
        length: 528
      },
      generateKeyPair: async function(){
        var k, a;
        k = (await CS.generateKey(this.keyParams, true, ['deriveKey'])['catch'](nullFunc));
        if (k === null) {
          return null;
        }
        a = (await CS.exportKey('spki', k.publicKey)['catch'](nullFunc));
        return a === null
          ? null
          : [k.privateKey, a];
      },
      generateHashPair: async function(){
        var a, b;
        a = (await CS.generateKey(this.deriveParams, true, ['sign'])['catch'](nullFunc));
        if (a === null) {
          return null;
        }
        a = (await CS.exportKey('raw', a)['catch'](nullFunc));
        if (a === null) {
          return null;
        }
        b = (await CS.digest('SHA-512', a)['catch'](nullFunc));
        if (b === null) {
          return null;
        }
        a = new Uint8Array(a);
        b = new Uint8Array(b);
        return [a, b];
      },
      importKey: function(k){
        return CS.importKey('spki', k, this.keyParams, true, [])['catch'](nullFunc);
      },
      importEcdhKey: function(k){
        return CS.importKey('raw', k, {
          name: 'AES-GCM'
        }, false, ['encrypt', 'decrypt'])['catch'](nullFunc);
      },
      deriveKey: function(privateK, publicK){
        publicK = {
          name: 'ECDH',
          'public': publicK
        };
        return CS.deriveKey(publicK, privateK, this.deriveParams, true, ['sign'])['catch'](nullFunc);
      },
      bufToBase64: function(buf){
        var a;
        a = new Uint8Array(buf);
        return btoa(String.fromCharCode.apply(null, a));
      },
      base64ToBuf: function(str){
        var a, b, c, d;
        a = atob(str);
        b = a.length;
        c = new Uint8Array(b);
        d = -1;
        while (++d < b) {
          c[d] = a.charCodeAt(d);
        }
        return c;
      },
      newSecret: function(){
        var CipherParams, CryptoData, SecretStorage;
        CipherParams = function(iv){
          this.name = 'AES-GCM';
          this.iv = iv;
          this.tagLength = 128;
        };
        CryptoData = function(data, params){
          this.data = data;
          this.params = params;
        };
        SecretStorage = function(manager, secret, key, iv){
          this.manager = manager;
          this.secret = secret;
          this.key = key;
          this.params = new CipherParams(iv);
        };
        SecretStorage.prototype = {
          encrypt: function(data, extended){
            var p;
            if (typeof data === 'string') {
              data = textEncode(data);
            }
            p = new CipherParams(this.params.iv.slice());
            data = CS.encrypt(p, this.key, data)['catch'](nullFunc);
            if (extended) {
              data = new CryptoData(data, p);
              this.next();
            }
            return data;
          },
          decrypt: function(data, params){
            if (typeof data === 'string') {
              data = textEncode(data);
            }
            if (!params) {
              return CS.decrypt(this.params, this.key, data)['catch'](nullFunc);
            }
            params = new CipherParams(params.iv.slice());
            this.next(params.iv);
            data = CS.decrypt(params, this.key, data)['catch'](nullFunc);
            return new CryptoData(data, params);
          },
          next: function(counter){
            var a, b, c, d, e;
            a = counter
              ? counter
              : this.params.iv;
            b = new DataView(a.buffer, 10, 2);
            c = bufToBigInt(a.slice(0, 10));
            d = b.getUint16(0, false);
            if ((e = ++c - 1208925819614629174706176n) >= 0) {
              c = e;
            }
            if ((e = ++d - 65536) >= 0) {
              d = e;
            }
            a.set(bigIntToBuf(c, 10), 0);
            b.setUint16(0, d, false);
            if (!counter) {
              this.secret.set(a, 32);
            }
            return this;
          },
          tag: function(){
            return bufToHex(this.secret.slice(-2));
          },
          save: function(){
            return this.manager('set', apiCrypto.bufToBase64(this.secret)) ? this : null;
          }
        };
        return async function(secret, manager){
          var k, c;
          switch (toString$.call(secret).slice(8, -1)) {
          case 'String':
            secret = apiCrypto.base64ToBuf(secret);
            break;
          case 'CryptoKey':
            secret = (await apiCrypto.cs.exportKey('raw', secret));
            secret = new Uint8Array(secret);
            if (secret[0] === 0) {
              secret = secret.slice(1);
            }
            break;
          default:
            return null;
          }
          if (secret.length < 44) {
            return null;
          }
          secret = secret.slice(0, 44);
          k = secret.slice(0, 32);
          c = secret.slice(32, 32 + 12);
          if ((k = (await apiCrypto.importEcdhKey(k))) === null) {
            return null;
          }
          return new SecretStorage(manager, secret, k, c);
        };
      }()
    };
  }();
  Config = function(){
    this.baseUrl = '';
    this.status200 = true;
    this.fullHouse = false;
    this.notNull = false;
    this.timeout = 20;
    this.retry = null;
    this.secret = null;
    this.headers = {
      'content-type': 'application/json; charset=utf-8'
    };
  };
  Config.prototype = {
    set: function(){
      var baseOptions;
      baseOptions = ['baseUrl', 'status200', 'fullHouse', 'notNull', 'timeout'];
      return function(o){
        var i$, ref$, len$, a, b;
        for (i$ = 0, len$ = (ref$ = baseOptions).length; i$ < len$; ++i$) {
          a = ref$[i$];
          if (o.hasOwnProperty(a)) {
            this[a] = o[a];
          }
        }
        if (o.headers) {
          this.headers = {};
          for (a in ref$ = o.headers) {
            b = ref$[a];
            this.headers[a.toLowerCase()] = b;
          }
        }
      };
    }()
  };
  RetryConfig = function(){
    this.count = 15;
    this.current = 0;
    this.expoBackoff = true;
    this.maxBackoff = 32;
    this.delay = 1;
  };
  ResponseData = function(){
    var RequestData, ResponseData;
    RequestData = function(){
      this.headers = null;
      this.data = null;
      this.crypto = null;
    };
    return ResponseData = function(){
      this.status = 0;
      this.headers = null;
      this.data = null;
      this.crypto = null;
      this.request = new RequestData();
    };
  }();
  FetchOptions = function(){
    this.method = 'GET';
    this.body = null;
    this.signal = null;
    this.headers = {};
    this.mode = 'cors';
  };
  FetchError = function(){
    var E;
    if (Error.captureStackTrace) {
      E = function(message, status){
        this.name = 'FetchError';
        this.message = message;
        this.status = status;
        Error.captureStackTrace(this, FetchError);
      };
    } else {
      E = function(message, status){
        this.name = 'FetchError';
        this.message = message;
        this.status = status;
        this.stack = new Error(message).stack;
      };
    }
    E.prototype = Error.prototype;
    return E;
  }();
  FetchData = function(config){
    var this$ = this;
    this.promise = null;
    this.response = new ResponseData();
    this.aborter = null;
    this.timer = 0;
    this.timerFunc = function(){
      this$.timer = 0;
      this$.aborter.abort();
    };
    this.retry = new RetryConfig();
    this.status200 = config.status200;
    this.fullHouse = config.fullHouse;
    this.notNull = config.notNull;
    this.timeout = 1000 * config.timeout;
  };
  FetchHandler = function(config){
    var handler;
    handler = function(url, options, data, callback){
      var responseHandler, successHandler, errorHandler;
      responseHandler = function(r){
        var h, a, b;
        if (data.timer) {
          clearTimeout(data.timer);
          data.timer = 0;
        }
        if (!r.ok || (r.status !== 200 && data.status200)) {
          throw new FetchError(r.statusText, r.status);
        }
        h = {};
        a = r.headers.entries();
        while (!(b = a.next()).done) {
          h[b.value[0].toLowerCase()] = b.value[1];
        }
        data.response.status = r.status;
        data.response.headers = h;
        if ((a = h['content-encoding']) === 'aes256gcm') {
          if (!config.secret) {
            throw new FetchError('unable to decrypt, no shared secret', r.status);
          }
          return r.arrayBuffer();
        }
        a = options.headers.accept || h['content-type'] || '';
        switch (0) {
        case a.indexOf('application/json'):
          return r.text().then(jsonDecode);
        case a.indexOf('application/octet-stream'):
          return r.arrayBuffer();
        default:
          return r.text();
        }
      };
      successHandler = async function(d){
        var res, sec, a, b;
        res = data.response;
        sec = config.secret;
        if (sec) {
          if (d && res.headers['content-encoding'] === 'aes256gcm') {
            a = sec.decrypt(d, res.request.crypto.params);
            if ((b = (await a.data)) === null) {
              sec.manager('error');
              throw new FetchError('failed to decrypt the response', res.status);
            }
            a.data = d;
            res.crypto = a;
            sec.save();
            a = options.headers.accept || res.headers['content-type'] || '';
            switch (0) {
            case a.indexOf('application/json'):
              d = jsonDecode(b);
              break;
            case a.indexOf('text/plain'):
              d = textDecode(b);
              break;
            default:
              d = b;
            }
          } else {
            sec.save();
          }
        }
        if (d === null && data.notNull) {
          d = {};
        }
        if (data.fullHouse) {
          res.data = d;
        } else {
          res = d;
        }
        if (callback) {
          callback(true, res);
        } else {
          data.promise.pending = false;
          data.promise.resolve(res);
        }
      };
      errorHandler = function(e){
        if (callback) {
          callback(false, e);
        } else {
          data.promise.pending = false;
          data.promise.resolve(e);
        }
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
      };
      if (data.timeout) {
        data.timer = setTimeout(data.timerFunc, data.timeout);
      }
      return fetch(url, options).then(responseHandler).then(successHandler)['catch'](errorHandler);
    };
    this.config = config;
    this.api = new Api(this);
    this.fetch = function(options, callback){
      var o, d, a, b, c;
      if (toString$.call(options).slice(8, -1) !== 'Object' || callback && typeof callback !== 'function') {
        return new Error('incorrect parameters');
      }
      o = new FetchOptions();
      d = new FetchData(config);
      if (options.hasOwnProperty('timeout') && (a = options.timeout) >= 0) {
        d.timeout = 1000 * a;
      }
      if (options.hasOwnProperty('status200')) {
        d.status200 = !!options.status200;
      }
      if (options.hasOwnProperty('fullHouse')) {
        d.fullHouse = !!options.fullHouse;
      }
      if (options.hasOwnProperty('notNull')) {
        d.notNull = !!options.notNull;
      }
      if (options.hasOwnProperty('method')) {
        o.method = options.method;
      } else if (options.data) {
        o.method = 'POST';
      }
      d.response.request.headers = import$(o.headers, config.headers);
      if (a = options.headers) {
        for (b in a) {
          o.headers[b.toLowerCase()] = a[b];
        }
      }
      if (a = config.secret) {
        o.headers['content-encoding'] = 'aes256gcm';
        o.headers['etag'] = a.next().tag();
      }
      if (c = options.data) {
        a = o.headers['content-type'];
        b = toString$.call(c).slice(8, -1);
        if (config.secret) {
          switch (0) {
          case a.indexOf('application/x-www-form-urlencoded'):
            o.headers['content-type'] = 'application/json';
            // fallthrough
          case a.indexOf('application/json'):
            if (b !== 'String' && !(c = jsonEncode(c))) {
              return new Error('failed to encode request data');
            }
            break;
          case a.indexOf('multipart/form-data'):
            if (b === 'String' || b === 'FormData') {
              return new Error('incorrect request data');
            }
            delete o.headers['content-type'];
            break;
          default:
            if (b !== 'String' && b !== 'ArrayBuffer') {
              return new Error('incorrect request data');
            }
          }
        } else {
          switch (0) {
          case a.indexOf('application/json'):
            if (b !== 'String' && (c = jsonEncode(c)) === null) {
              return new Error('failed to encode request data');
            }
            break;
          case a.indexOf('application/x-www-form-urlencoded'):
            if ((b !== 'String' && b !== 'URLSearchParams') && !(c = newQueryString(c))) {
              return new Error('failed to encode request data');
            }
            break;
          case a.indexOf('multipart/form-data'):
            if ((b !== 'String' && b !== 'FormData') && !(c = newFormData(c))) {
              return new Error('failed to encode request data');
            }
            if (b !== 'String') {
              delete o.headers['content-type'];
            }
            break;
          default:
            if (b !== 'String' && b !== 'ArrayBuffer') {
              return new Error('incorrect request data');
            }
          }
        }
        o.body = d.response.request.data = c;
      }
      d.aborter = options.aborter
        ? options.aborter
        : new AbortController();
      o.signal = d.aborter.signal;
      a = d.retry;
      if (b = config.retry) {
        for (c in a) {
          a[c] = b[c];
        }
      }
      if (b = options.retry) {
        if (toString$.call(b).slice(8, -1) === 'Object') {
          for (c in a) {
            if (b.hasOwnProperty(c)) {
              a[c] = b[c];
            }
          }
        } else {
          a.count = b;
        }
      }
      a.current = 0;
      a.maxBackoff = 1000 * a.maxBackoff;
      if (!callback) {
        d.promise = newPromise(d.aborter);
      }
      a = options.url
        ? config.baseUrl + options.url
        : config.baseUrl;
      if (b = config.secret) {
        c = b.encrypt(o.body, true);
        c.data.then(function(e){
          o.body = c.data = e;
          d.response.request.crypto = c;
          if (!o.signal.aborted) {
            handler(a, o, d, callback);
          }
        })['catch'](function(e){
          if (callback) {
            callback(false, e);
          } else {
            d.promise.pending = false;
            d.promise.resolve(e);
          }
        });
      } else {
        handler(a, o, d, callback);
      }
      return callback
        ? d.aborter
        : d.promise;
    };
  };
  Api = function(handler){
    var handshakeLocked;
    this.create = newInstance(handler.config);
    this.post = function(url, data, callback){
      var o;
      o = {
        url: url,
        method: 'POST',
        data: data ? data : ''
      };
      return handler.fetch(o, callback);
    };
    this.get = function(url, callback){
      var o;
      o = {
        url: url,
        method: 'GET',
        data: ''
      };
      return handler.fetch(o, callback);
    };
    if (!apiCrypto) {
      return;
    }
    handshakeLocked = false;
    this.handshake = async function(url, storeManager){
      var k, hash, x, c, b, a, i;
      if (handshakeLocked) {
        return false;
      }
      if (!storeManager) {
        if (k = handler.config.secret) {
          handler.config.secret = null;
          apiCrypto.secretManagersPool['delete'](k.manager);
          k.manager('destroy', '');
        }
        return true;
      }
      if (apiCrypto.secretManagersPool.has(storeManager)) {
        console.log('httpFetch: secret store manager must be unique');
        return false;
      }
      handshakeLocked = true;
      if (k = storeManager('get')) {
        k = handler.config.secret = (await apiCrypto.newSecret(k, storeManager));
        handshakeLocked = false;
        return !!k;
      }
      if (!(hash = (await apiCrypto.generateHashPair()))) {
        handshakeLocked = false;
        return false;
      }
      x = false;
      c = 4;
      while (--c) {
        if (!(k = (await apiCrypto.generateKeyPair()))) {
          break;
        }
        b = {
          url: url,
          method: 'POST',
          data: k[1],
          headers: {
            'content-type': 'application/octet-stream',
            'etag': 'exchange'
          },
          fullHouse: false,
          timeout: 0
        };
        a = (await handler.fetch(b));
        if (!a || a instanceof Error) {
          break;
        }
        if ((a = (await apiCrypto.importKey(a))) === null) {
          break;
        }
        if ((a = (await apiCrypto.deriveKey(k[0], a))) === null) {
          break;
        }
        if ((k = (await apiCrypto.newSecret(a, storeManager))) === null) {
          break;
        }
        b.headers.etag = 'verify';
        if ((b.data = (await k.encrypt(hash[0]))) === null) {
          break;
        }
        a = (await handler.fetch(b));
        if (!a || !(a instanceof ArrayBuffer)) {
          break;
        }
        if ((i = a.byteLength) !== 0) {
          a = new Uint8Array(a);
          if ((b = hash[1]).byteLength !== i) {
            break;
          }
          while (--i >= 0) {
            if (a[i] !== b[i]) {
              break;
            }
          }
          if (i === -1) {
            x = true;
            break;
          }
        }
      }
      if (x && (handler.config.secret = k.save())) {
        apiCrypto.secretManagersPool.set(k.manager);
      }
      handshakeLocked = false;
      return x;
    };
  };
  ApiHandler = function(handler){
    this.get = function(f, key){
      switch (key) {
      case 'secret':
        return !!handler.config.secret;
      default:
        if (handler.config.hasOwnProperty(key)) {
          return handler.config[key];
        }
      }
      if (handler.api[key]) {
        return handler.api[key];
      }
      return null;
    };
    this.set = function(f, key, val){
      if (handler.config.hasOwnProperty(key)) {
        switch (key) {
        case 'baseURL':
          if (typeof val === 'string') {
            handler.config[key] = val;
          }
          break;
        case 'status200':
        case 'notNull':
        case 'fullHouse':
          handler.config[key] = !!val;
          break;
        case 'timeout':
          if ((val = parseInt(val)) >= 0) {
            handler.config[key] = val;
          }
        }
      }
      return true;
    };
  };
  newFormData = function(){
    var add;
    add = function(data, item, key){
      var b, i$, len$, a;
      switch (toString$.call(item).slice(8, -1)) {
      case 'Object':
        b = Object.getOwnPropertyNames(item);
        if (key) {
          for (i$ = 0, len$ = b.length; i$ < len$; ++i$) {
            a = b[i$];
            add(data, item[a], key + '[' + a + ']');
          }
        } else {
          for (i$ = 0, len$ = b.length; i$ < len$; ++i$) {
            a = b[i$];
            add(data, item[a], a);
          }
        }
        break;
      case 'Array':
        key = key ? key + '[]' : '';
        b = item.length;
        a = -1;
        while (++a < b) {
          add(data, item[a], key);
        }
        break;
      case 'HTMLInputElement':
        if (item.type === 'file' && item.files.length) {
          add(data, item.files, key);
        }
        break;
      case 'FileList':
        if ((b = item.length) === 1) {
          data.append(key, item[0]);
        } else {
          a = -1;
          while (++a < b) {
            data.append(key + '[]', item[a]);
          }
        }
        break;
      case 'Null':
        data.append(key, '');
        break;
      default:
        data.append(key, item);
      }
      return data;
    };
    return function(o){
      return add(new FormData(), o, '');
    };
  }();
  newQueryString = function(){
    var add;
    add = function(list, item, key){
      var b, i$, len$, a;
      switch (toString$.call(item).slice(8, -1)) {
      case 'Object':
        b = Object.getOwnPropertyNames(item);
        if (key) {
          for (i$ = 0, len$ = b.length; i$ < len$; ++i$) {
            a = b[i$];
            add(list, item[a], key + '[' + a + ']');
          }
        } else {
          for (i$ = 0, len$ = b.length; i$ < len$; ++i$) {
            a = b[i$];
            add(list, item[a], a);
          }
        }
        break;
      case 'Array':
        key = key ? key + '[]' : '';
        b = item.length;
        a = -1;
        while (++a < b) {
          add(list, item[a], key);
        }
        break;
      case 'Null':
        list[list.length] = encodeURIComponent(key) + '=';
        break;
      default:
        list[list.length] = encodeURIComponent(key) + '=' + encodeURIComponent(item);
      }
      return list;
    };
    return function(o){
      return add([], o, '').join('&');
    };
  }();
  newPromise = function(aborter){
    var a, b;
    a = null;
    b = new Promise(function(resolve){
      a = resolve;
    });
    b.pending = true;
    b.resolve = a;
    b.controller = aborter;
    b.abort = b.cancel = function(){
      aborter.abort();
    };
    return b;
  };
  newInstance = function(baseConfig){
    return function(userConfig){
      var config, a, b;
      config = new Config();
      if (baseConfig) {
        config.set(baseConfig);
      }
      if (userConfig) {
        config.set(userConfig);
      }
      a = new FetchHandler(config);
      b = new ApiHandler(a);
      return new Proxy(a.fetch, b);
    };
  };
  return newInstance(null)(null);
}();
if (httpFetch && typeof module !== 'undefined') {
  module.exports = httpFetch;
}
function import$(obj, src){
  var own = {}.hasOwnProperty;
  for (var key in src) if (own.call(src, key)) obj[key] = src[key];
  return obj;
}