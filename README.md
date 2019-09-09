# httpFetch

[![](https://data.jsdelivr.com/v1/package/npm/http-fetch-json/badge)](https://www.jsdelivr.com/package/npm/http-fetch-json)

*Individual [fetch API](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API) wrapper for the browser*


## Syntax
### `httpFetch.post(url, data[, callback(ok, res)])`
### `httpFetch.get(url[, callback(ok, res)])`

#### Parameters

- **`url`** - request destination string, reference to the web resource (prefixed by **`baseUrl`** config)
- **`data`** - string or serializable object to be sent as the request body
- **`callback`**(*optional*) - result handler function, influences return value
  - **`ok`** - boolean, indicates the request state (influenced by **`status200`** config)
  - **`res`** - server response object (influenced by **`noEmpty`** config) or [`Error`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Error) object

#### Return value

With the callback set, the function returns an instance of [`AbortController`](https://developer.mozilla.org/en-US/docs/Web/API/AbortController) on success or `null` on failure. The [`Promise`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise) is returned when callback omitted.


#### Example

```JavaScript
httpFetch.get('/api/drivers/list', function(ok, res) {
  if (ok)
  {
    // show JSON response from the server
    console.log(res);
  }
  else
  {
    // show Error message
    console.log(res.message);
  }
});
```
#### Demo

[Random quote fetcher](https://codepen.io/determin1st/pen/PoYJmvJ?editors=0010)


## Extended syntax
### `httpFetch(options[, callback(ok, res)])`

#### Parameters

- **`options`** - object with:
  - **`url`** - request destination string, reference to the web resource (prefixed by **`baseUrl`** config)
  - **`data`**(*optional*) - string or serializable object to be sent as the request body
  - **`method`**(*optional*) - request method string, for example: `GET`, `POST`. the default is determined according to the data
  - **`timeout`**(*optional*) - a period of time in seconds, after which the request will be aborted
  - **`retry`**(*optional*) - integer count or object with parameters
- **`callback`**(*optional*) - result handler function, influences return value
  - **`ok`** - boolean, indicates the request state (influenced by **`status200`** config)
  - **`res`** - server response object (influenced by **`noEmpty`** config) or [`Error`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Error) object

#### Return value

When the callback is present, function returns an instance of `AbortController` on success or `null` on failure. `Promise` is returned when callback omitted.


## Instance Configuration
### `httpFetch.create(config)`

#### Parameters

- **`config`** - object with:
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

...


## Install

CDN:
```html
<script src="https://cdn.jsdelivr.net/npm/http-fetch-json@1/httpFetch.js"></script>
```

NPM:
```bash
$ npm install http-fetch-json
```


