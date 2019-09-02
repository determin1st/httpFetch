// Generated by LiveScript 1.6.0
'use strict';
var httpFetch, toString$ = {}.toString;
httpFetch = function(){
  var api, defaults, HandlerOptions, FetchOptions, responseHandler, handler;
  api = {};
  api[typeof fetch] = true;
  api[typeof AbortController] = true;
  api[typeof Proxy] = true;
  if (api['undefined']) {
    return null;
  }
  defaults = {
    timeout: 20,
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json'
    }
  };
  HandlerOptions = function(url, method){
    this.url = url;
    this.method = method;
    this.data = '';
    this.timeout = defaults.timeout;
  };
  FetchOptions = function(method){
    this.method = method;
    this.headers = defaults.headers;
    this.body = '';
    this.signal = null;
  };
  responseHandler = function(r){
    return r.text().then(function(r){
      var e;
      if (r) {
        try {
          return JSON.parse(r);
        } catch (e$) {
          e = e$;
          throw new Error('Incorrect server response: ' + e.message + ': ' + r);
        }
      }
      return null;
    });
  };
  handler = function(opts, callback){
    var a, o, abrt, timeout;
    if (toString$.call(opts).slice(8, -1) !== 'Object' || typeof callback !== 'function') {
      return false;
    }
    if (opts.hasOwnProperty('method')) {
      a = opts.method;
    } else if (opts.data) {
      a = 'POST';
    } else {
      a = 'GET';
    }
    o = new FetchOptions(a);
    if (opts.data) {
      o.body = typeof opts.data === 'string'
        ? opts.data
        : JSON.stringify(opts.data);
    }
    a = opts.hasOwnProperty('timeout')
      ? opts.timeout
      : defaults.timeout;
    if (a >= 1) {
      abrt = new AbortController();
      o.signal = abrt.signal;
      timeout = setTimeout(function(){
        abrt.abort();
      }, 1000 * a);
    }
    debugger;
    fetch(opts.url, o).then(responseHandler).then(function(r){
      if (timeout) {
        clearTimeout(timeout);
      }
      callback(true, r);
    })['catch'](function(e){
      callback(false, e);
    });
    return true;
  };
  api = {
    post: function(url, data, callback){
      var o;
      o = new HandlerOptions(url, 'POST');
      if (data) {
        o.data = data;
      }
      return handler(o, callback);
    },
    get: function(url, callback){
      return handler(new HandlerOptions(url, 'GET'), callback);
    }
  };
  return new Proxy(handler, {
    get: function(me, key){
      if (api.hasOwnProperty(key)) {
        return api[key];
      }
      return null;
    },
    set: function(me, key, val){
      return true;
    }
  });
}();
if (httpFetch && typeof module !== 'undefined') {
  module.exports = httpFetch;
}