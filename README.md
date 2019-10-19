# httpFetch

[![](https://data.jsdelivr.com/v1/package/npm/http-fetch-json/badge)](https://www.jsdelivr.com/package/npm/http-fetch-json)

*Individual [fetch API](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API) wrapper for the browser (experimental)*


## Syntax
### `httpFetch(options[, callback(ok, res)])`

#### Parameters

- **`options`** - object with:
  - **`url`** - request destination string, reference to the web resource (prefixed by **`baseUrl`** config)
  - **`data`**(*optional*) - string or serializable object to be sent as the request body
  - **`headers`**(*optional*) - object with request headers
  - **`method`**(*optional*) - request method string, for example: `GET`, `POST`. the default is determined automatically, according to the data
  - **`mode`**(*optional*) - fetch mode: `cors`, `no-cors`, `same-origin`, the default is determined automatically
  - **`timeout`**(*optional*) - time to wait for server response (in seconds)
  - **`retry`**(*optional*) - integer count or object with parameters
  - **`aborter`**(*optional*) - abort controller to use, enables multiple request cancellation
- **`callback`**(*optional*) - result handler function, influences return value
  - **`ok`** - boolean, indicates the request state (influenced by **`status200`** config)
  - **`res`** - server response object (influenced by **`noEmpty`** config) or [`Error`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Error) object

#### Return value

[`AbortController`](https://developer.mozilla.org/en-US/docs/Web/API/AbortController) (callback) or [`Promise`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise) on success, [`null`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/null) on failure.


## Short syntax
### `httpFetch.post(url, data[, callback(ok, res)])`
### `httpFetch.get(url[, callback(ok, res)])`

#### Parameters

- **`url`** - request destination string, reference to the web resource (prefixed by **`baseUrl`** config)
- **`data`** - string or serializable object to be sent as the request body
- **`callback`**(*optional*) - result handler function, influences return value
  - **`ok`** - boolean, indicates the request state (influenced by **`status200`** config)
  - **`res`** - server response object (influenced by **`noEmpty`** config) or [`Error`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Error) object

#### Return value

[`AbortController`](https://developer.mozilla.org/en-US/docs/Web/API/AbortController) (callback) or [`Promise`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise) on success, [`null`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/null) on failure.



## Instance Configuration
### `httpFetch.create(config)`

#### Parameters

- **`config`** - object with:
  - **`headers`**
  - **`baseUrl`**
  - **`status200`**
  - **`noEmpty`**
  - **`timeout`**
  - **`retry`**
    - **`count`** - positive integer, `15` attempts by default
    - **`expoBackoff`** - boolean, activates [exponential backoff algorithm](https://en.wikipedia.org/wiki/Exponential_backoff), `true` by default
    - **`maxBackoff`** - positive integer, `32` seconds by default
    - **`delay`** - positive integer or array of integers, used when **`expoBackoff`** is `false`, `1` second by default

#### Return value

new [`httpFetch`](https://github.com/determin1st/httpFetch) instance


## Examples


#### Get with callback
```javascript
httpFetch.get('/api/drivers/list', function(ok, res) {
  if (ok)
  {
    // everything is okay..
  }
  else
  {
    // Error occured..
  }
});
```
#### Get with async/await
```javascript
var res = await httpFetch.get('/api/drivers/list');
if (res instanceof Error)
{
  // Error occured..
}
else
{
  // everything is okay..
}
```
#### Get with Promise
```javascript
httpFetch.get('/api/drivers/list')
  .then(function(res) {
    if (res instanceof Error)
    {
      // Error occured, note, that .catch() is not needed!
    }
    else
    {
      // everything is okay..
    }
  });
```
#### Configuring instance
```javascript
// set previously obtained authorization token to the main instance configuration
httpFetch.headers.Authorization = 'token '+access_token;
// all fetches, from now on, will carry this header if not replaced explicitly.
// ...
```
```javascript
// this is a safer variant which creates a new instance with derived configuration
var myFetch = httpFetch.create({
  headers: {
    Authorization: 'token '+access_token
  }
});
```

#### File uploads
#### Cancellation
#### Retry


## Demos

*While browsing demos, use F12 devtools console to see more details*.

[Random quote fetcher](https://raw.githack.com/determin1st/httpFetch/master/test-1/index.html) ([codepen](https://codepen.io/determin1st/pen/PoYJmvJ?editors=0010))

[Authorizing at Google](https://raw.githack.com/determin1st/httpFetch/master/test-2/index.html): getting user name/avatar

[Authorizing at GitHub](https://raw.githack.com/determin1st/httpFetch/master/test-4/index.html): exchanging code for token, getting user e-mail

[Error handling](http://raw.githack.com/determin1st/httpFetch/master/test-3/index.html): connection timeout, incorrect response body, bad http statuses


## Install

CDN:
```html
<script src="https://cdn.jsdelivr.net/npm/http-fetch-json@1/httpFetch.js"></script>
```

NPM:
```bash
$ npm install http-fetch-json
```

