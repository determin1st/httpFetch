// Generated by LiveScript 1.6.0
'use strict';
var httpFetch, toString$ = {}.toString;
httpFetch = function(){
  var api, FetchOptions, FetchError, Config, RetryOptions, HandlerOptions, HandlerData, fetchHandler, newInstance, Api, apiHandler;
  api = [typeof fetch, typeof AbortController, typeof Proxy];
  if (api.includes('undefined')) {
    console.log('httpFetch: missing requirements');
    return null;
  }
  FetchOptions = function(method){
    this.method = method;
    this.body = null;
    this.signal = null;
    this.headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json'
    };
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
  Config = function(){
    this.baseUrl = '';
    this.status200 = true;
    this.noEmpty = false;
    this.timeout = 20;
    this.retry = null;
    this.headers = null;
  };
  RetryOptions = function(){
    this.count = 15;
    this.current = 0;
    this.expoBackoff = true;
    this.maxBackoff = 32;
    this.delay = 1;
  };
  HandlerOptions = function(url, method, config){
    this.url = url;
    this.method = method;
    this.data = '';
    this.timeout = config.timeout;
    this.retry = config.retry;
  };
  HandlerData = function(){
    this.aborter = new AbortController();
    this.timeout = 0;
    this.timer = 0;
    this.retry = new RetryOptions();
  };
  fetchHandler = function(config){
    var responseHandler, textParser, handler;
    responseHandler = function(r){
      if (!r.ok || (r.status !== 200 && config.status200)) {
        throw new FetchError(r.statusText, r.status);
      }
      return r.text().then(textParser);
    };
    textParser = function(r){
      var e;
      if (r) {
        try {
          return JSON.parse(r);
        } catch (e$) {
          e = e$;
          throw new Error('Incorrect response body: ' + e.message + ': ' + r);
        }
      }
      return config.noEmpty ? {} : null;
    };
    handler = function(url, options, data, callback){
      if (data.timeout) {
        data.timer = setTimeout(function(){
          data.aborter.abort();
          data.timer = 0;
        }, data.timeout);
      }
      return fetch(url, options).then(responseHandler).then(function(r){
        if (data.timer) {
          clearTimeout(data.timer);
          data.timer = 0;
        }
        if (callback) {
          callback(true, r);
        }
      })['catch'](function(e){
        var a, b;
        if (data.timer) {
          clearTimeout(data.timer);
          data.timer = 0;
        }
        if (callback) {
          a = callback(false, e);
        } else {
          a = true;
        }
        if (a && (a = data.retry).count && a.current < a.count) {
          if (a.expoBackoff) {
            b = Math.pow(2, a.current) + Math.floor(1001 * Math.random());
            if (b > a.maxBackoff) {
              b = a.maxBackoff;
            }
          } else {
            if (typeof a.delay === 'number') {
              b = 1000 * a.delay;
            } else {
              if (a.current <= (b = a.delay.length - 1)) {
                b = 1000 * a.delay[a.current];
              } else {
                b = 1000 * a.delay[b];
              }
            }
          }
          ++a.current;
          setTimeout(function(){
            handler(url, options, data, callback);
          }, b);
        }
      });
    };
    return function(options, callback){
      var a, o, d, b, c;
      if (toString$.call(options).slice(8, -1) !== 'Object') {
        return null;
      }
      a = options.hasOwnProperty('method')
        ? options.method
        : options.data ? 'POST' : 'GET';
      o = new FetchOptions(a);
      d = new HandlerData();
      if (config.headers) {
        import$(o.headers, config.headers);
      }
      if (options.headers) {
        import$(o.headers, options.headers);
      }
      if (options.data) {
        o.body = typeof options.data === 'string'
          ? options.data
          : JSON.stringify(options.data);
      }
      o.signal = d.aborter.signal;
      a = options.hasOwnProperty('timeout')
        ? options.timeout
        : config.timeout;
      if (a >= 1) {
        d.timeout = 1000 * a;
      }
      a = d.retry;
      if (b = config.retry) {
        for (c in a) {
          a[c] = b[c];
        }
      }
      if (options.hasOwnProperty('retry') && (b = options.retry)) {
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
      a = options.url
        ? config.baseUrl + options.url
        : config.baseUrl;
      handler(a, o, d, callback);
      if (callback) {
        return d.aborter;
      }
      return null;
    };
  };
  newInstance = function(base){
    return function(config){
      var c, a, h;
      c = new Config();
      if (base) {
        for (a in c) {
          c[a] = base[a];
        }
      }
      for (a in c) {
        if (config.hasOwnProperty(a)) {
          c[a] = config[a];
        }
      }
      h = fetchHandler(c);
      h.config = c;
      h.api = new Api(h);
      return new Proxy(h, apiHandler);
    };
  };
  Api = function(handler){
    this.post = function(url, data, callback){
      var options;
      options = new HandlerOptions(url, 'POST', handler.config);
      if (data) {
        options.data = data;
      }
      return handler(options, callback);
    };
    this.get = function(url, callback){
      return handler(new HandlerOptions(url, 'GET', handler.config), callback);
    };
    this.create = newInstance(handler.config);
  };
  apiHandler = {
    get: function(me, key){
      if (typeof me.api[key] === 'function') {
        return me.api[key];
      }
      if (me.config.hasOwnProperty(key)) {
        return me.config[key];
      }
      return null;
    },
    set: function(me, key, val){
      return true;
    }
  };
  return newInstance(null)(new Config());
}();
if (httpFetch && typeof module !== 'undefined') {
  module.exports = httpFetch;
}
function import$(obj, src){
  var own = {}.hasOwnProperty;
  for (var key in src) if (own.call(src, key)) obj[key] = src[key];
  return obj;
}