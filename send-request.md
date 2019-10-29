# SEND-REQUEST

Simplifies sending HTTP requests:

* Automaticaly translates data from Red values to url-encoded strings and JSON. 
* Handles authentication.
* Makes handling HTTP headers easier.
* Translates response to Red values based on MIME type.

## Usage

`SEND-REQUEST link method`

* `link [url!]` is HTTP(S) address
* `method [word!]` is one of HTTP methods (`GET`, `HEAD`, `POST`, `PUT`,
	`DELETE`, `CONNECT`, `OPTIONS`, `TRACE`).

### Refinements

#### /only

Return reply only without headers.

#### /data content

Data to send with HTTP request. Data are automatically converted to proper
encoding:

* with `GET` method, content (expected to be `block!`) is translated to
	url-encoded string and appended to the link, e.g.: 
	`send-request/data link 'GET [x: 2 y: 2]` results in `link?x=1&y=2`.

* with other methods, content is treated based on type: `block!` is also 
	translated to url-encoded string passed as data and `Content-Type`
	field in the header is set to `application/x-www-form-urlencoded`
	(with one small exception: block with first value of `JSON` is treaded as
	JSON array).

* `map!` is treated as JSON and `Content-Type` is set accordingly. So you
	don't have to care about sending JSON requests, it's handled
	automatically.

* `string!` is passed as is, so you have to set `Content-Type` manually.

#### /with headers

Headers to send with requests. Should be `map!` or `block!` of key/value
pairs.

#### /auth auth-type auth-data

Authentication method and data.

Supported methods: `basic`, `bearer`.

* `basic` method expects data to be `block!` with two values, **user** and
**password**.

* `bearer` method expects data to be `string!` with token.

#### /raw

Return raw data and do not try to decode them. Useful for debugging purposes.

#### /verbose

Print request informations. Useful for debugging purposes.

#### /debug

Set debug words:

* `req` - block with two values: `link` and `data`. Link is address of HTTP
request, in case of `GET` method with url-encoded data. `data` is block of
headers and encoded data.

* `raw-reply` - binary reply returned from server

* `loaded-reply` - reply converted to `string!`. Unlike Red, `send-request`
tries to convert also non-UTF8 strings using very naive method (no codepage
conversion), so the results may vary.

## Examples

#### GET request

Simple request with no data (in such case, use just `read http://example.org`
instead):

`send-request http://example.org 'GET`

GET request with FORM data:

`send-request/data http://example.org 'GET [name: "Albert Einstein" age: 140]`

GET request with headers:

`send-request/with http://example.org 'GET [Accept-Charset: utf-8]`

GET request with basic authentication:

`send-request/auth http://example.org 'GET 'basic ["username" "my-secret-passw0rd"]`

GET request with bearer token:

`send-request/auth http://example.org 'GET 'bearer "abcd1234cdef5678"`

#### POST request

POST request with HTTP FORM data:

`send-request/data http://example.org 'POST [name: "Albert Einstein" age: 140]`

POST request with JSON data:

`send-request/data http://example.org 'POST #(name: "Alber Einstein" age: 140)`

