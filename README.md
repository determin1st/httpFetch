# httpFetch

*Personal [fetch API](https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API) abstraction for the browser*


## Syntax

### `httpFetch.post(url, data, callback(ok, res))`
### `httpFetch.get(url, callback(ok, res))`

#### Parameters

- **`url`** - request destination, reference to the web resource
- **`data`** - string or serializable object to be sent as the request body
- **`callback`** - function which will handle result
  - **`ok`** - boolean flag
  - **`res`** - server response object (`null` for empty responses) or [`Error`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Error) object

#### Return value

Boolean. Indicates that fetch was started and the callback will run.

#### Examples

```JavaScript
httpFetch.post('/api/drivers/create', {
  name: 'John Smith',
  age: 60,
  licenseId: '123456789'
}, function(ok, res) {
  // check for errors
  if (ok)
  {
    // show JSON response from the server
    console.log(res);
  }
  else
  {
    // show error message
    console.log(res.message);
  }
});
```

```JavaScript
httpFetch.get('/api/drivers/list', function(ok, res) {
  // check for errors
  if (ok)
  {
    // show JSON response from the server
    console.log(res);
  }
  else
  {
    // show error message
    console.log(res.message);
  }
});
```


## Install

CDN:
```html
<script src="https://cdn.jsdelivr.net/gh/determin1st/httpFetch@master/httpFetch.js"></script>
```

NPM:
```bash
$ npm install httpFetch
```
