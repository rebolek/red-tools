# SEND-REQUEST

Simplifies sending HTTP requests:

* Automaticaly translates data from Red values to url-encoded strings and JSON. 
* Handles authentication.
* Makes handling HTTP headers easier.
* Translates response to Red values based on MIME type.

## Usage

`SEND-REQUEST link method`

* `link` is HTTP(S) address
* `method` is one of HTTP methods (`GET`, `HEAD`, `POST`, `PUT`, `DELETE`,
	`CONNECT`, `OPTIONS`, `TRACE`).

### Refinements

#### /only

Return only reply without headers.

#### /data content

* with `GET` method, content (expected to be `block!`) is translated to
	url-encoded string and appended to the link, e.g.: 
	`send-request/data link 'GET [x: 2 y: 2]` results in `link?x=1&y=2`.

* with other methods, content is treated based on type: `block!` is also 
	translated to url-encoded string passed as data and `Content-Type`
	field in the header is set to `application/x-www-form-urlencoded`
	(with one small exception useful only for a very small niche).

* `map!` is treated as JSON and `Content-Type` is set accordingly. So you
	don't have to care about sending JSON requests, it's handled
	automatically.

* `string!` is passed as it was before you have to set `Content-Type`
	manually, no change here.

#### /with headers

Headers to send with requests.

#### /auth auth-type auth-data

Authentication method and data.

Supported methods: `basic`, `bearer`.

#### /raw

Return raw data and do not try to decode them.

#### /verbose

Print request informations.

#### /debug

Set debug words (see source for details).
