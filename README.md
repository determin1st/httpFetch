# httpFetch
*Individual [fetch API](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API)
wrapper for the browser ([experimental](https://developer.mozilla.org/en-US/docs/MDN/Contribute/Guidelines/Conventions_definitions#Experimental))*
[![Spider Mastermind](https://raw.githack.com/determin1st/httpFetch/master/logo.jpg)](http://www.nathanandersonart.com/)
[![](https://data.jsdelivr.com/v1/package/npm/http-fetch-json/badge)](https://www.jsdelivr.com/package/npm/http-fetch-json)


## Tests
- [**random quote fetcher**](https://raw.githack.com/determin1st/httpFetch/master/test-1/index.html): get a saying from the famous author.
- [**authorizing at Google**](https://raw.githack.com/determin1st/httpFetch/master/test-2/index.html): getting user name & avatar.
- [**authorizing at GitHub**](https://raw.githack.com/determin1st/httpFetch/master/test-4/index.html): exchanging code for token, getting user e-mail ([their fault!](https://github.com/isaacs/github/issues/330)).
- [**error handling**](http://raw.githack.com/determin1st/httpFetch/master/test-3/index.html): connection problem, incorrect response body, bad http statuses, etc.
- [**self cancellation**](http://raw.githack.com/determin1st/httpFetch/master/test-5/index.html): if request is running - cancel it, then, make a new request (step on yourself).
- [**image upload**](http://raw.githack.com/determin1st/httpFetch/master/test-6/index.html): upload single image file with some metadata and show it ([FormData](https://developer.mozilla.org/en-US/docs/Web/API/FormData) handling).
- [**encryption**](http://raw.githack.com/determin1st/httpFetch/master/test-7/index.html): do a [handshake](https://en.wikipedia.org/wiki/Diffie%E2%80%93Hellman_key_exchange) and echo encrypted messages (remote session + secret)([FireFox only](https://en.wikipedia.org/wiki/Firefox)).
- [**retry redirects**](http://raw.githack.com/determin1st/httpFetch/master/test-8/index.html): retry syntax and custom redirects (manual is wasted by spec).


## Base syntax
### `httpFetch(options[, callback(ok, res)])`
#### Parameters
- **`options`** - an [object](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object)
with:
  ---
  basic
  - **`url`** - request destination [string](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String)
, reference to the web resource (prefixed by **`baseUrl`**)
  - **`data`**(*optional*) - [content](https://developer.mozilla.org/en-US/docs/Glossary/Type)
to be sent as the request body
  ---
  native [fetch()](https://developer.mozilla.org/en-US/docs/Web/API/WindowOrWorkerGlobalScope/fetch)
  - **`method`**(*optional*) - request method [string](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String)
  - **`mode`**(*optional*) - fetch mode [string](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String)
  - **`credentials`**(*optional*) - [string](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String)
of a set
  - **`cache`**(*optional*) - [string](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String)
of a set
  - **`redirect`**(*optional*) - [string](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String)
of a [set](https://stackoverflow.com/a/42717388/7128889)
  - **`referrer`**(*optional*) - [url](https://developer.mozilla.org/en-US/docs/Glossary/URL) [string](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String)
  - **`referrerPolicy`**(*optional*) - [string](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String)
of a [set](https://hacks.mozilla.org/2016/03/referrer-and-cache-control-apis-for-fetch/)
  - **`integrity`**(*optional*) - [subresource integrity](https://developer.mozilla.org/en-US/docs/Web/Security/Subresource_Integrity) [string](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String)
  - **`keepalive`**(*optional*) - [boolean](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Boolean)
flag
  ---
  advanced
  - **`status200`**(*optional*) - [boolean](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Boolean)
flag
  - **`fullHouse`**(*optional*) - [boolean](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Boolean)
flag
  - **`notNull`**(*optional*) - [boolean](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Boolean)
flag
  - **`promiseReject`**(*optional*) - [boolean](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Boolean)
flag
  - **`timeout`**(*optional*) - [integer](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number)
connection timeout (in seconds)
  - **`redirectCount`**(*optional*) - [integer](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number)
maximal number of manual redirect (**disabled** because of [political dogma](https://fetch.spec.whatwg.org/)
)
  - **`retryCount`**(*optional*) - [integer](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number)
maximal number of retries api will do (`0` is none by default, `-1` is unlimited)
  - **`aborter`**(*optional*) - an [abort controller](https://developer.mozilla.org/en-US/docs/Web/API/AbortController)
, may be used for cancellation
  - **`headers`**(*optional*) - an [object](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object)
with request headers
  ---
- **`callback`**(*optional*) - result handler [function](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Function)
, influences return value
  - **`ok`** - boolean, indicates the request state (influenced by **`status200`** config)
  - **`res`** - server response object (influenced by **`notNull`** config) or [`Error`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Error) object
#### Returns
[`Promise`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise) (not callback) or
[`AbortController`](https://developer.mozilla.org/en-US/docs/Web/API/AbortController) (callback)


## Short syntax
### `httpFetch(url[, callback(ok, res)])`
### `httpFetch(url[, data[, callback(ok, res)]])`
#### Parameters
- **`url`** - same as `options.url`, [string](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String)
- **`data`** - same as `options.data`, [content](https://developer.mozilla.org/en-US/docs/Glossary/Type),
  - when **not set** `options.method` will be `GET`
  - when **set** `options.method` will be `POST`
- **`callback`** - same as `callback`, [function](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Function)
#### Returns
[`Promise`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise) (not callback) or
[`AbortController`](https://developer.mozilla.org/en-US/docs/Web/API/AbortController) (callback)


## Result syntax
### Positive style (the default)
#### async/await
```javascript
var res = await httpFetch('resource');
if (res instanceof Error)
{
  // FetchError
}
else if (!res)
{
  // empty response, JSON falsy values
}
else
{
  // success
}
```
#### Promise
```javascript
httpFetch('resource')
  .then(function(res) {
    if (res instanceof Error)
    {
      // FetchError
    }
    else if (!res)
    {
      // empty response, JSON falsy values
    }
    else
    {
      // success
    }
  });
```
#### callback
```javascript
httpFetch('resource', function(ok, res) {
  if (ok && res)
  {
    // success
  }
  else if (!res)
  {
    // empty response or JSON falsy values
  }
  else
  {
    // FetchError
  }
});
```
### Positive style, when `notNull`
#### async/await
```javascript
var res = await soFetch('resource');
if (res instanceof Error)
{
  // FetchError, empty response, JSON NULL
}
else
{
  // success, JSON falsy values but JSON NULL
}
```
#### Promise
```javascript
soFetch('resource')
  .then(function(res) {
    if (res instanceof Error)
    {
      // FetchError, empty response, JSON NULL
    }
    else
    {
      // success, JSON falsy values but JSON NULL
    }
  });
```
#### callback
```javascript
soFetch('resource', function(ok, res) {
  if (ok)
  {
    // success, JSON falsy values but JSON NULL
  }
  else
  {
    // FetchError, empty response, JSON NULL
  }
});
```
### Negative style, when `promiseReject`
#### Promise
```javascript
oFetch('resource')
  .then(function(res) {
    if (res)
    {
      // success
    }
    else
    {
      // empty response, JSON falsy values
    }
  })
  .catch(function(err)
  {
    // FetchError
  });
```
#### async/await
```javascript
try
{
  var res = await soFetch('resource');
  if (res)
  {
    // success
  }
  else
  {
    // empty response, JSON falsy values
  }
}
catch (err)
{
  // FetchError
}
```


## Result types
- [JSON](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/JSON)
  - with `application/json`
- [USVString](https://developer.mozilla.org/en-US/docs/Web/API/USVString)
  - with `text/*`
- [Blob](https://developer.mozilla.org/en-US/docs/Web/API/Blob)
  - with `image/*`
  - with `audio/*`
  - with `video/*`
- [FormData](https://developer.mozilla.org/en-US/docs/Web/API/FormData)
  - with `multipart/form-data`
- [ArrayBuffer](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/ArrayBuffer)
  - with `application/octet-stream`
  - ...
- [null](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/null)
  - with `application/json` when **`JSON NULL`**
  - with `application/octet-stream` when not **`byteLength`**
  - with `image/*`, `audio/*`, `video/*` when not **`size`**
  - when **`EMPTY RESPONSE`**
- [FetchError](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Error)
  - when connection fails
  - when **`HTTP STATUS`** is not `200` and **`status200`**
  - when **`EMPTY RESPONSE`** and **`notNull`**
  - when **`JSON NULL`** and **`notNull`**
  - ...

## FetchError
```javascript
if (res instanceof Error)
{
  // checking FetchError identifier allows to
  // determine category of the error:
  switch (res.id)
  {
    case 0:
      ///
      // connection problems:
      // - connection timed out
      // - wrong CORS headers
      // - unacceptable HTTP STATUS
      // - etc
      ///
      console.log(res.message);   // error details
      console.log(res.response);  // request + response data, full house
      break;
    case 1:
      ///
      // something's wrong with the response data:
      // - empty response
      // - incorrect content type
      // - etc
      ///
      break;
    case 2:
      ///
      // security compromised
      ///
      break;
    case 3:
      ///
      // incorrect API usage
      // - wrong syntax used
      // - something's wrong with the response data
      // - internal problem
      ///
      break;
    case 4:
      ///
      // aborted programmatically:
      // - cancelled before the request was made
      // - cancelled in the process, before response arrived
      ///
      break;
    case 5:
      ///
      // unclassified
      ///
      break;
  }
}
```


## Retry syntax
#### async/await
```javascript
var count = 5;
```
#### Promise
```javascript
```
#### async callback
```javascript
var count = 5;
httpFetch(url, async function(ok, res) {
  if (ok)
  {
    // success
  }
  else
  {
    // check for specific error
    if (res.id === 0)
    {
      // check counter
      if (--count)
      {
        // wait for some time
        await delay(1000);
        // retry
        return true;
      }
    }
  }
  return false;// finish, don't retry
});
```


## New instance
### `httpFetch.create(config)`
#### Parameters
- **`config`** - an [object](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object)
with: ...
#### Returns
[instanceof](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/instanceof)
[`httpFetch`](https://github.com/determin1st/httpFetch)
```javascript
var a = httpFetch.create();
var b = a.create();

if ((a instanceof httpFetch) &&
    (b instanceof httpFetch))
{
  // true!
}
```
```javascript
/**
* This section may be safely skipped
*/
var soFetch = httpFetch.create({
  ///
  // to shorten url parameter in future invocations,
  // that is super-handy option
  //
  baseUrl: 'http://localhost:8080/api/', // '' by default
  ///
  // same as in fetch() init parameter
  // https://developer.mozilla.org/en-US/docs/Web/API/WindowOrWorkerGlobalScope/fetch
  //
  mode: 'same-origin',            // 'cors'
  credentials:  'include',        // 'same-origin'
  cache: 'no-store',              // 'default'
  redirect: 'manual',             // 'follow'
  referrer: 'http://example.fake',// ''
  referrerPolicy: 'same-origin',  // ''
  integrity: knownSRI,            // ''
  keepalive: true,                // false
  ///
  // when your API works solid and optimal,
  // there is nothing special in http responses and
  // only "HTTP 200 OK" is used as a positive result
  // (free from transfer / internal server problems)
  // but with sloppy and external api,
  // which uses statuses for data exchange,
  // setting this option false may help to handle those cases
  //
  status200: false, // true by default
  ///
  // to get everything,
  // both request and reponse with headers and stuff,
  // this option may be set true
  //
  fullHouse: true, // false by default
  ///
  // empty response (without content body) may be identified as `null`,
  // but if remote API is designed without empty responses
  // it may be groupped with errors, for convenience
  //
  notNull: true, // false by default
  ///
  // Promise will resolve everything by default,
  // if try/catch or .catch() constructs are used to handle the result,
  // this option must be enabled
  //
  promiseReject: true, // false by default
  ///
  // setting connection timeout to zero,
  // will make request wait forever (until server response)
  //
  timeout: 0, // 20 by default
  ///
  // custom request headers
  //
  headers: {
    // when response arrives, fetch handler will try to parse it
    // strictly, according to accepted content type:
    accept: 'application/json',
    // remote API may require specific authorization headers set,
    // exact names and formats depend on implementation:
    authorization: accessToken
  }
});
```


## Advanced syntax
### shortcut methods
#### `httpFetch.json`
- `application/json` (**the default**)
#### `httpFetch.text`
- `text/plain`
#### `httpFetch.form`
- `multipart/form-data`
- `application/x-www-form-urlencoded`
```javascript
```


## KISS API
Always use POST method. (Keep It Simple Stupid)
```javascript
// instead of GET method,
// you may POST:
res = await httpFetch(url, {});       // EMPTY OBJECT
res = await httpFetch(url, undefined);// EMPTY BODY
res = await httpFetch(url, null);     // JSON NULL
// it may easily expand to
// list filters:
res = await httpFetch(url, {
  categories: ['one', 'two'],
  flag: true
});
// item extras:
res = await httpFetch(url, {
  fullDescription: true,
  ownerInfo: true
});
// otherwise,
// parametrized GET will quickly swamp into:
res = await httpFetch(url+'?flags=123&names=one,two&isPulluted=true');

// DO NOT use multiple/mixed notations:
res = await httpFetch(url+'?more=params', params);
res = await httpFetch(url+'/more/params', params);
// DO unified:
res = await httpFetch(url, Object.assign(params, {more: "params"}));

// by default, any HTTP status is considered error,
// except HTTP 200 OK:
if (res instanceof Error) {
  console.log(res.status);// not 200
}
else {
  console.log(res.status);// always 200
}
```


## TODO
#### Download
#### Streams
#### Resumable
#### Loader


## Try
CDN:
```html
<script src="https://cdn.jsdelivr.net/npm/http-fetch-json@1/httpFetch.js"></script>
```
NPM:
```bash
npm i http-fetch-json
```

## Links
https://javascript.info/fetch-api


