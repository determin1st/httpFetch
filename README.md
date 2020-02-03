# httpFetch
[![](https://data.jsdelivr.com/v1/package/npm/http-fetch-json/badge)](https://www.jsdelivr.com/package/npm/http-fetch-json)

*Individual [fetch API](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API)
wrapper for the browser ([experimental](https://developer.mozilla.org/en-US/docs/MDN/Contribute/Guidelines/Conventions_definitions#Experimental))*


## Base syntax
### `httpFetch(options[, callback(ok, res)])`
#### Parameters
- **`options`** - object with:
  - **`url`** - request destination [string](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String)
, reference to the web resource (prefixed by **`baseUrl`**)
  - **`data`**(*optional*) - to be sent as the request body
  - **`method`**(*optional*) - request method [string](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String)
  - **`mode`**(*optional*) - fetch mode [string](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String)
  - **`credentials`**(*optional*) - ...
  - **`cache`**(*optional*) - ...
  - **`redirect`**(*optional*) - ...
  - **`referrer`**(*optional*) - ...
  - **`referrerPolicy`**(*optional*) - ...
  - **`integrity`**(*optional*) - ...
  - **`keepalive`**(*optional*) - ...
  - **`timeout`**(*optional*) - [integer](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number)
time (in seconds) to wait for server response
  - **`retry`**(*optional*)
  - **`aborter`**(*optional*) - an [abort controller](https://developer.mozilla.org/en-US/docs/Web/API/AbortController)
  - **`headers`**(*optional*) - an [object](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object)
with request headers
, may be used for multiple requests cancellation
- **`callback`**(*optional*) - result handler function, influences return value
  - **`ok`** - boolean, indicates the request state (influenced by **`status200`** config)
  - **`res`** - server response object (influenced by **`notNull`** config) or [`Error`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Error) object
#### Return value
[`Promise`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise) (no callback) or
[`AbortController`](https://developer.mozilla.org/en-US/docs/Web/API/AbortController) (with callback) or
[`Error`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Error) (failure)


## Creating an instance
### `httpFetch.create(options)`
```javascript
var soFetch = httpFetch.create({
  ///
  // to shorten url parameter in future invocations,
  // that is super-handy option
  //
  baseUrl: 'http://localhost:8080/api/', // '' by default (change)
  ///
  // when your API works solid and optimal,
  // there is nothing special in http responses and
  // only "HTTP 200 OK" is used as a positive result
  // (free from transfer / internal server problems)
  // but with sloppy and external api,
  // which uses statuses for data exchange,
  // this option may help to handle those cases
  //
  status200: false, // true by default (better to leave)
  ///
  // empty response (without content body) may be identified as `null`,
  // but when remote API is designed without empty responses
  // it may be treated as an error, check result handling section
  //
  notNull: true, // false by default (change, maybe)
  ///
  // setting connection timeout to zero,
  // will make request wait forever (until server response)
  //
  timeout: 0, // 20 by default (change if needed)
  ///
  // ...
  //
  retry: ?, // ?
  ///
  // same as in [fetch() init parameter](https://developer.mozilla.org/en-US/docs/Web/API/WindowOrWorkerGlobalScope/fetch)
  //
  mode: 'same-origin', // 'cors' by default (change if needed)
  ///
  // same as in [fetch() init parameter](https://developer.mozilla.org/en-US/docs/Web/API/WindowOrWorkerGlobalScope/fetch)
  //
  credentials: 'include', // 'same-origin' by default (change if needed)
  ///
  // same as in [fetch() init parameter](https://developer.mozilla.org/en-US/docs/Web/API/WindowOrWorkerGlobalScope/fetch)
  //
  cache: 'no-store', // 'default' by default (change if needed)
  ///
  // same as in [fetch() init parameter](https://developer.mozilla.org/en-US/docs/Web/API/WindowOrWorkerGlobalScope/fetch)
  //
  redirect: 'manual', // 'follow' by default ([beware](https://stackoverflow.com/a/42717388/7128889)!)
  ///
  // same as in [fetch() init parameter](https://developer.mozilla.org/en-US/docs/Web/API/WindowOrWorkerGlobalScope/fetch)
  //
  referrer: 'http://example.fake', // '' by default ([beware](https://hacks.mozilla.org/2016/03/referrer-and-cache-control-apis-for-fetch/)!)
  referrerPolicy: 'same-origin', // '' by default
  ///
  // same as in [fetch() init parameter](https://developer.mozilla.org/en-US/docs/Web/API/WindowOrWorkerGlobalScope/fetch)
  //
  integrity: knownSRI, // '' by default ([beware](https://developer.mozilla.org/en-US/docs/Web/Security/Subresource_Integrity)!)
  ///
  // same as in [fetch() init parameter](https://developer.mozilla.org/en-US/docs/Web/API/WindowOrWorkerGlobalScope/fetch)
  //
  keepalive: true, // false by default (change if needed)
  ///
  // custom request headers
  //
  headers: {
    // when response arrives, fetch handler will try to parse it
    // according to accepted content type setting:
    accept: 'application/json'
    // remote API may require specific authorization headers set,
    // exact names and formats depend on implementation:
    authorization: 'token '+accessToken
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

## Result handling patterns
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
### When notNull
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
httpFetch.get('resource', function(ok, res) {
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

## Shortcuts
### content-type
#### `httpFetch.json`
- `application/json` (the default)
#### `httpFetch.form`
- `multipart/form-data`
- `application/x-www-form-urlencoded`
#### `httpFetch.text`
- `text/*`
#### `httpFetch.bin`
- `application/octet-stream`
### method
#### `httpFetch.post(url, data[, callback(ok, res)])`
#### `httpFetch.get(url[, callback(ok, res)])`


## File upload
## Cancellation
## Retry
## Encryption


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


