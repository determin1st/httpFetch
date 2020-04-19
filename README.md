# httpFetch
*Individual [fetch API](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API)
wrapper for [the browser](https://en.wikipedia.org/wiki/Web_browser)
([experimental](https://developer.mozilla.org/en-US/docs/MDN/Contribute/Guidelines/Conventions_definitions#Experimental),
[reactionary](https://en.wikipedia.org/wiki/Reactionary))*
<details>
  <summary>overview</summary>

  The thing is pretty fast as it doesnt try to connect worlds,
  but rather lives in it's own native environment (the browser).
  So it will catch up with you faster than you may think.

  HTTP request and response routine is super boring
  but standard procedure for all kinds of stuff.

  While some folks having troubles with so called "native" apis,
  the best of us are using wrappers (self-made or other's libs - doesnt matter).

  The thing is a kind of a wrapper, but armed with extra options and routes
  which may or may not happen with you during the HTTP request/response battle.

  It's more advanced that any other tool which try to keep pace with the NODE's world
  because it uses (currently) experimental features of the browser.
  But it may be more aggressive in your environment -
  only modern syntax, only modern apis (but not the approach).
  As far as time flows, the previous statement becomes falsy.

  So, the attempt of escaping your doom is futile:
  Face it one-to-one with the **Spider Mastermind**!
</details>

[![Spider Mastermind](https://raw.githack.com/determin1st/httpFetch/master/tests/logo.jpg)](http://www.nathanandersonart.com/)
[![](https://data.jsdelivr.com/v1/package/npm/http-fetch-json/badge)](https://www.jsdelivr.com/package/npm/http-fetch-json)


## Tests
- [**Fail**](http://raw.githack.com/determin1st/httpFetch/master/tests/test-1.html): check everything
- [**Cancellation**](http://raw.githack.com/determin1st/httpFetch/master/tests/test-2.html): cancel anything
- **Encryption**: encrypt everything ([FF only](https://en.wikipedia.org/wiki/Firefox))
- [**Retry**](http://raw.githack.com/determin1st/httpFetch/master/tests/test-4.html): restart anything
- [**Download**](http://raw.githack.com/determin1st/httpFetch/master/tests/test-5.html): download anything
- **Upload**: upload anything
- **Streams**: stream something
- **Mix**: mix everything


## Try
<details>
<summary>ES5 script (classic)</summary>

  ```html
  <!-- CDN (stable) -->
  <script src="https://cdn.jsdelivr.net/npm/http-fetch-json@2/httpFetch.js"></script>

  <!-- GIT (lastest) -->
  <script src="http://raw.githack.com/determin1st/httpFetch/master/httpFetch.js"></script>
  ```
</details>
<details>
<summary>ES6 module</summary>

  ```javascript
  // TODO
  ```
</details>
<details>
<summary>get the code</summary>

  ```bash
  # GIT (lastest)
  git clone https://github.com/determin1st/httpFetch

  # NPM (stable)
  npm i http-fetch-json
  ```
</details>




## Syntax
### `httpFetch(options [, callback])`
### `httpFetch(url, data [, callback])`
### `httpFetch(url [, callback])`
#### Parameters
- **`options`** - an [object][3] with:
  ---
  <details>
  <summary>base</summary>

  | name       | type        | default | description |
  | :---       | :---:       | :---:   | :---        |
  | **`url`**  | [string][2] |         | reference to the local or remote web resource (auto-prefixed with **`baseUrl`** if doesn't contain [sheme](https://en.wikipedia.org/wiki/Uniform_Resource_Identifier)) |
  | **`data`** | [any][1]    |         | content to be sent as the request body |
  </details>

  ---
  <details>
  <summary>native fetch</summary>

  | name                 | type         | default       | description |
  | :---                 | :---:        | :---:         | :---        |
  | **`method`**         | [string][2]  |               | [HTTP request method][101] (detected automatically) |
  | **`mode`**           | [string][2]  | `cors`        | [fetch][100] mode |
  | **`credentials`**    | [string][2]  | `same-origin` | to automatically send cookies |
  | **`cache`**          | [string][2]  | `default`     | the [cache mode][102] to use for the request |
  | **`redirect`**       | [string][2]  | `follow`      | the [redirect][103] [mode][104] to use. `manual` is [screwed by spec author](https://github.com/whatwg/fetch/issues/601) |
  | **`referrer`**       | [string][2]  |               | [referrer url][105] |
  | **`referrerPolicy`** | [string][2]  |               | the [referrer policy][106] to use |
  | **`integrity`**      | [string][2]  |               | the [subresource integrity][107] value of the request |
  | **`keepalive`**      | [boolean][4] | `false`       | allows the request to [outlive the page][108] |
  </details>

  ---
  <details>
  <summary>advanced</summary>

  | name                | type         | default | description |
  | :---                | :---:        | :---:   | :---        |
  | **`status200`**     | [boolean][4] | `true`  | to consider only [HTTP STATUS 200 OK][109] |
  | **`notNull`**       | [boolean][4] | `false` | to consider only **nonempty** [HTTP response body][110] and **not** [JSON NULL][111] |
  | **`fullHouse`**     | [boolean][4] | `false` | to include everything, request and response, data and headers |
  | **`promiseReject`** | [boolean][4] | `false` | promise will reject with [Error][5] |
  | **`timeout`**       | [integer][6] | `20`    | request will abort in the given [delay in seconds][112] |
  | **`redirectCount`** | [integer][6] | `5`     | manual redirects limit (functional **only** with http status **300**) |
  | **`aborter`**       | [aborter][8] |         | to cancel request with given controller |
  | **`headers`**       | [object][3]  | `{..}`  | [request headers][114] |
  | **`parseResponse`** | [string][2]  | `data`  | `data` is to parse all the content to proper [content type][113], `stream` for **`FetchStream`**, otherwise, raw [response][7] |
  </details>

  ---
- **`callback(ok, res)`** - optional [result handler function](https://developer.mozilla.org/en-US/docs/Glossary/Callback_function)
  ---
  - **`ok`** - [boolean][4] flag, indicates the result type
  - **`res`** - response result [data][1] or [FetchError][5]
#### Returns
[`Promise`][10] (no callback) or [`AbortController`][8] (callback)


## Result handling
##### Optimistic style (the default)
<details>
  <summary>async/await</summary>

  ```javascript
  var res = await httpFetch('/resource');
  if (res instanceof Error)
  {
    // FetchError
  }
  else if (!res)
  {
    // JSON falsy values
  }
  else
  {
    // success
  }
  ```
</details>
<details>
  <summary>promise</summary>

  ```javascript
  httpFetch('/resource')
    .then(function(res) {
      if (res instanceof Error)
      {
        // FetchError
      }
      else if (!res)
      {
        // JSON falsy values
      }
      else
      {
        // success
      }
    });
  ```
</details>
<details>
  <summary>callback</summary>

  ```javascript
  httpFetch('/resource', function(ok, res) {
    if (ok && res)
    {
      // success
    }
    else if (!res)
    {
      // JSON falsy values
    }
    else
    {
      // FetchError
    }
  });
  ```
</details>

##### Optimistic, when `notNull` (recommended)
<details>
  <summary>custom instance</summary>

  ```javascript
  var oFetch = httpFetch.create({
    notNull: true
  });
  ```
</details>
<details>
  <summary>async/await</summary>

  ```javascript
  var res = await oFetch('/resource');
  if (res instanceof Error)
  {
    // FetchError
  }
  else
  {
    // success
  }
  ```
</details>
<details>
  <summary>promise</summary>

  ```javascript
  oFetch('/resource')
    .then(function(res) {
      if (res instanceof Error)
      {
        // FetchError
      }
      else
      {
        // success
      }
    });
  ```
</details>
<details>
  <summary>callback</summary>

  ```javascript
  oFetch('resource', function(ok, res) {
    if (ok)
    {
      // success
    }
    else
    {
      // FetchError
    }
  });
```
</details>

##### Pessimistic style, when `promiseReject`
<details>
  <summary>custom instance</summary>

  ```javascript
  var pFetch = httpFetch.create({
    promiseReject: true
  });
  ```
</details>
<details>
  <summary>async/await</summary>

  ```javascript
  try
  {
    var res = await pFetch('/resource');
    if (res)
    {
      // success
    }
    else
    {
      // JSON falsy values
    }
  }
  catch (err)
  {
    // FetchError
  }
  ```
</details>
<details>
  <summary>promise</summary>

  ```javascript
  oFetch('/resource')
    .then(function(res) {
      if (res)
      {
        // success
      }
      else
      {
        // JSON falsy values
      }
    })
    .catch(function(err)
    {
      // FetchError
    });
  ```
</details>

##### Pessimistic, when `promiseReject` and `notNull`
<details>
  <summary>custom instance</summary>

  ```javascript
  var pFetch = httpFetch.create({
    notNull: true,
    promiseReject: true
  });
  ```
</details>
<details>
  <summary>async/await</summary>

  ```javascript
  try
  {
    var res = await pFetch('/resource');// success
  }
  catch (err)
  {
    // FetchError
  }
  ```
</details>
<details>
  <summary>promise</summary>

  ```javascript
  oFetch('/resource')
    .then(function(res) {
      // success
    })
    .catch(function(err)
    {
      // FetchError
    });
  ```
</details>


## Result types
- [JSON](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/JSON)
  - `application/json`
- [String](https://developer.mozilla.org/en-US/docs/Web/API/USVString)
  - `text/*`
- [ArrayBuffer][12]
  - `application/octet-stream`
  - ...
- [Blob](https://developer.mozilla.org/en-US/docs/Web/API/Blob)
  - `image/*`
  - `audio/*`
  - `video/*`
- [FormData][13]
  - `multipart/form-data`
- [null][11]
  - `application/json` when [`JSON NULL`][111]
  - `application/octet-stream` when not **`byteLength`**
  - `image/*`, `audio/*`, `video/*` when not **`size`**
  - when [HTTP response body][110] is empty
- [FetchStream][15]
  - when **`parseResponse`** is `stream`
- [FetchError][5]
  - when [fetch()][100] fails
  - when [unsuccessful HTTP status code][115]
  - when not [HTTP STATUS 200 OK][109] and **`status200`**
  - when [`JSON NULL`][111] and **`notNull`**
  - when [HTTP response body][110] is empty and **`notNull`**
  - ...

## FetchError
<details>
  <summary>error categories</summary>

  ```javascript
  if (res instanceof Error)
  {
    switch (res.id)
    {
      case 0:
        ///
        // connection problems:
        // - connection timed out
        // - wrong CORS headers
        // - unsuccessful HTTP STATUSes (not in 200-299 range)
        // - readable stream failed
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
        // - something's wrong with the request data
        // - internal bug
        ///
        break;
      case 4:
        ///
        // aborted programmatically:
        // - canceled parsing, before the request was made
        // - canceled fetching, before the response arrived
        // - canceled parsing, after the response arrived
        // - stream canceled
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
</details>


# Advanced
<details>
  <summary>httpFetch.create</summary>

  ### `httpFetch.create(config)`
  #### Parameters
  - **`config`** - an [object][3] with instance options
  ---
  <details>
  <summary>base</summary>

  | name          | type          | default | description |
  | :---          | :---:         | :---:   | :---        |
  | **`baseUrl`** | [string][2]   | ``      | |
  | **`mounted`** | [boolean][4]  | `false` | |
  </details>

  #### Description
  Creates a new [instance of][116] of [`httpFetch`][0]
  #### Examples
  ```javascript
  var a = httpFetch.create();
  var b = a.create();

  if ((a instanceof httpFetch) &&
      (b instanceof httpFetch))
  {
    // true!
  }
  ```
</details>
<details>
  <summary>httpFetch.cancel</summary>

  ### `httpFetch.cancel()`
  #### Description
  Cancels all running fetches of the instance
</details>
<details>
  <summary>httpFetch.form</summary>

  ### `httpFetch.form(url, data[, callback(ok, res)])`
  ### `httpFetch.form(options[, callback(ok, res)])`
  #### Description
  [httpFetch][0] operates with [JSON][111] content by default.
  This shortcut method allows to send a `POST` request
  with body conforming to one of the [form enctypes][117]:
  - `application/x-www-form-urlencoded`: [query string](https://en.wikipedia.org/wiki/Query_string)
  - `multipart/form-data`: [`FormData`][13] with attachments
  - `text/plain`: [plaintext][2]
  The proper [content type][113] will be detected automatically.
  #### Parameters
  Same as [`httpFetch`][0]
  #### Examples
  ```javascript
  // CLIENT (JS)
  // let's send a plain content without files,
  // there is no need in FormData format, so
  // it will be automaticly detected as
  // x-www-form-urlencoded:
  res = httpFetch.form(url, {
    param1: 1,
    param2: 2,
    param3: 3
  });
  ```
  ```php
  # SERVER (PHP)
  # get parameters and calculate their sum:
  $sum = $_POST['param1'] + $_POST['param2'] + $_POST['param3'];
  # respond with JSON
  echo json_encode($sum);
  # and quit
  exit;
  ```
  ```javascript
  // CLIENT (JS)
  // wait for the response and display it:
  console.log(await res);// 6
  ```
  ```javascript
  // CLIENT (JS)
  // let's send another request with file attached,
  // the body will be sent as
  // multipart/form-data:
  res = await httpFetch.form(url, {
    param1: 1,
    param2: 2,
    param3: 3,
    fileInput: document.querySelector('input[type="file"]')
  });
  // SERVER's $_FILES will be populated with uploaded file,
  // but the response/result will be the same:
  console.log(res);// 6
  ```
</details>


## KISS API
<details>
  <summary>overview</summary>

  What exactly **is** the [REST API](https://en.wikipedia.org/wiki/Representational_state_transfer)?
  In a nutshell, it's only a collection of [endpoints](https://stackoverflow.com/questions/2122604/what-is-an-endpoint#47573997):
  > Endpoints are important aspects of interacting with server-side web APIs, as they specify where resources lie that can be accessed by third party software. Usually the access is via a URI to which HTTP requests are posted, and from which the response is thus expected.

  The [original definition](https://www.ics.uci.edu/~fielding/pubs/dissertation/rest_arch_style.htm)
  of the REST **does not** restrict or explicitly specify
  certain [HTTP methods][101] to use with, there is no [CRUD](https://ru.wikipedia.org/wiki/CRUD)
  in there. Check the link and try to find it, if you doubt.

  Still, some dumb dumbies are unable to differentiate the origin and
  the mutatated forms of the term, but thats not the reason why **KISS** word is used.

  The **KISS** (**K**eep **I**t **S**imple **S**tupid) is how the **REST** is implemented.

  What is [AJAX](https://en.wikipedia.org/wiki/Ajax_(programming)) then?
  Well, thats also an implementation of the REST (or a subset).
  It is bound to the **JavaScript**, **XML** and [XMLHttpRequest](https://en.wikipedia.org/wiki/XMLHttpRequest).
  Generally, you say that **jQuery**, **axios**, **superagent** or
  other lib is **AJAX** if it utilizes **XMLHttpRequest** api.
  ...

  What about [RPC](https://en.wikipedia.org/wiki/Remote_procedure_call)?
  ...

</details>
<details>
  <summary>how</summary>

  #### use **POST** method
  ```javascript
  // instead of GET method, you may POST:
  res = await httpFetch(url, {});       // EMPTY OBJECT
  res = await httpFetch(url, undefined);// EMPTY BODY
  res = await httpFetch(url, null);     // JSON NULL
  // it may easily expand to
  // into list filters:
  res = await httpFetch(url, {
    categories: ['one', 'two'],
    flag: true
  });
  // or item extras:
  res = await httpFetch(url, {
    fullDescription: true,
    ownerInfo: true
  });
  // OTHERWISE,
  // parametrized GET will swamp into:
  res = await httpFetch(url+'?flags=123&names=one,two&isPulluted=true');

  // DO NOT use multiple/mixed notations:
  res = await httpFetch(url+'?more=params', params);
  res = await httpFetch(url+'/more/params', params);
  // DO unified:
  res = await httpFetch(url, Object.assign(params, {more: "params"}));

  // by default,
  // any HTTP status, except 200 is a FetchError:
  if (res instanceof Error) {
    console.log(res.status);
  }
  else {
    console.log(res.status);// 200
  }
  ```
</details>

## Links
https://javascript.info/fetch-api

https://tom.preston-werner.com/2010/08/23/readme-driven-development.html

https://code.tutsplus.com/tutorials/why-youre-a-bad-php-programmer--net-18384

[0]: https://github.com/determin1st/httpFetch
[1]: https://developer.mozilla.org/en-US/docs/Glossary/Type
[2]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String
[3]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object
[4]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Boolean
[5]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Error
[6]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number
[7]: https://developer.mozilla.org/en-US/docs/Web/API/Response
[8]: https://developer.mozilla.org/en-US/docs/Web/API/AbortController
[9]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Function
[10]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise
[11]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/null
[12]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/ArrayBuffer
[13]: https://developer.mozilla.org/en-US/docs/Web/API/FormData
[14]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/JSON
[15]: https://developer.mozilla.org/en-US/docs/Web/API/ReadableStream

[100]: https://developer.mozilla.org/en-US/docs/Web/API/WindowOrWorkerGlobalScope/fetch
[101]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods
[102]: https://developer.mozilla.org/en-US/docs/Web/API/Request/cache
[103]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Redirections
[104]: https://stackoverflow.com/a/42717388/7128889
[105]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Referer
[106]: https://hacks.mozilla.org/2016/03/referrer-and-cache-control-apis-for-fetch
[107]: https://developer.mozilla.org/en-US/docs/Web/Security/Subresource_Integrity
[108]: https://developer.mozilla.org/en-US/docs/Web/API/Navigator/sendBeacon
[109]: https://tools.ietf.org/html/rfc2616#section-10.2.1
[110]: https://en.wikipedia.org/wiki/HTTP_message_body
[111]: https://www.json.org/json-en.html
[112]: https://en.wikipedia.org/wiki/Timeout_%28computing%29
[113]: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Type
[114]: https://tools.ietf.org/html/rfc2616#section-5.3
[115]: https://tools.ietf.org/html/rfc2616#section-10.2
[116]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/instanceof
[117]: https://developer.mozilla.org/en-US/docs/Web/API/HTMLFormElement/enctype

---
<style type="text/css">
  summary {font-size:1.2em;font-weight:bold;color:skyblue;}
</style>

