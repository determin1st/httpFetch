# httpFetch
[![](https://data.jsdelivr.com/v1/package/npm/http-fetch-json/badge)](https://www.jsdelivr.com/package/npm/http-fetch-json)

*Individual [fetch API](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API)
wrapper for the browser ([experimental](https://developer.mozilla.org/en-US/docs/MDN/Contribute/Guidelines/Conventions_definitions#Experimental))*


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
  - **`timeout`**(*optional*) - [integer](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number)
connection timeout (in seconds)
  - **`aborter`**(*optional*) - an [abort controller](https://developer.mozilla.org/en-US/docs/Web/API/AbortController)
, may be used for cancellation
  - **`headers`**(*optional*) - an [object](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object)
with request headers
  ---
- **`callback`**(*optional*) - result handler function, influences return value
  - **`ok`** - boolean, indicates the request state (influenced by **`status200`** config)
  - **`res`** - server response object (influenced by **`notNull`** config) or [`Error`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Error) object
#### Returns
[`Promise`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise) (no callback) or
[`AbortController`](https://developer.mozilla.org/en-US/docs/Web/API/AbortController) (with callback) or


## Creating an instance
### `httpFetch.create(options)`
```javascript
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

## Creating a request (invocation)
```
soFetch({
  ///
  // ...
  //
});
```

## Handling the result
### Default
#### with async/await
```javascript
var res = await soFetch.get('resource');
if (res instanceof Error)
{
  // error
}
else if (!res)
{
  // empty response
}
else
{
  // success
}
```
#### with Promise
```javascript
var promise = soFetch.get('resource')
  .then(function(res) {
    if (res instanceof Error)
    {
      // error
    }
    else if (!res)
    {
      // empty response
    }
    else
    {
      // success
    }
  });
```
#### with callback
```javascript
var abortController = soFetch.get('resource', function(ok, res) {
  if (ok && res)
  {
    // success
  }
  else if (!res)
  {
    // empty response
  }
  else
  {
    // error
  }
});
```
### When `notNull` is true
#### with async/await
```javascript
var res = await soFetch.get('resource');
if (res instanceof Error)
{
  // error
}
else
{
  // success
}
```
#### with callback
```javascript
soFetch.get('resource', function(ok, res) {
  if (ok)
  {
    // success
  }
  else
  {
    // error
  }
});
```


## Result types
- [JSON](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/JSON)
  - `application/json`
- [USVString](https://developer.mozilla.org/en-US/docs/Web/API/USVString)
  - `text/*`
- [Blob](https://developer.mozilla.org/en-US/docs/Web/API/Blob)
  - `image/*`
  - `audio/*`
  - `video/*`
- [FormData](https://developer.mozilla.org/en-US/docs/Web/API/FormData)
  - `multipart/form-data`
- [ArrayBuffer](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/ArrayBuffer)
  - `application/octet-stream`
  - `*`
- [null](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/null)
  - `application/json`
  - `application/octet-stream`
  - `image/*`
  - `audio/*`
  - `video/*`
  - when response is empty and **`notNull`** is `false`
- [Error](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Error)
  - when error occurs
  - when response is empty and **`notNull`** is `true`


## Shortcuts
### method
#### `httpFetch.post(url, data[, callback(ok, res)])`
#### `httpFetch.get(url[, callback(ok, res)])`
### content-type
#### `httpFetch.json`
- `application/json` (the default)
#### `httpFetch.form`
- `multipart/form-data`
- `application/x-www-form-urlencoded`
#### `httpFetch.text`
- `text/*`


## Examples
### Enforce result type
### File upload
### Cancellation
### Retry
### Encryption


## Demos
*While browsing demos, use F12 devtools console to see more details*.

[Random quote fetcher](https://raw.githack.com/determin1st/httpFetch/master/test-1/index.html) ([codepen](https://codepen.io/determin1st/pen/PoYJmvJ?editors=0010))

[Authorizing at Google](https://raw.githack.com/determin1st/httpFetch/master/test-2/index.html): getting user name & avatar

[Authorizing at GitHub](https://raw.githack.com/determin1st/httpFetch/master/test-4/index.html): exchanging code for token, getting user e-mail ([CORS headers are BROKEN!](https://github.com/isaacs/github/issues/330))

[Error handling](http://raw.githack.com/determin1st/httpFetch/master/test-3/index.html): connection timeout, incorrect response body, bad http statuses

[Self cancellation](http://raw.githack.com/determin1st/httpFetch/master/test-5/index.html): if request is running - cancel it, then, make a new request. (step on yourself)

[Image upload](http://raw.githack.com/determin1st/httpFetch/master/test-6/index.html): uploads single image file with some metadata and shows it ([FormData](https://developer.mozilla.org/en-US/docs/Web/API/FormData) content handling)

[Encryption](http://raw.githack.com/determin1st/httpFetch/master/test-7/index.html): handshake and echo encrypted message (remote session + secret)


## Install
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


