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

## Data handling

With most requests, user wants to send some data. This is handled with
`/data` refinement which accepts `content` value that can be of multiple
datatypes:

### string!

The most basic type is `string!` which is passed as is.

```
send-request/data server 'POST "key1=val1&key2=val2"
```

### map! and object!

`map!` and `object!` are converted to JSON and `Content-Type` is set to
`application/json`

```
send-request/data server 'POST #(key1: "val1" key2: 2)

send-request/data server 'POST context [key1: "val1" key2: 2]
```

### block!

`block!` can be used as multi-puropse dialect. Simplest variant are pairs
of `set-word!` keys and values that are represented as `application/x-www-form-urlencoded`:

```
send-request/data server 'POST [key1: "val1" key2 2]
```

`block!` can be used with `GET` method also, in that case it's translated to
URL:

```
send-request/data http://www.example.com 'GET [key: "val1" key2 2]
== http://www.example.com?key1=val1&key2=2
```

It's possible to send JSON array using `block!`. In such case use `#json`
as first value in block, everything else is treated as values in JSON array:

```
send-request/data server 'POST [#JSON this is json array]
== (...) {["this", "is", "json", "array"]}
```

`block!` can also be used to send `multipart/form-data`. Use `#multi` as a
first value to specify that what follows are form data. They use same format
as plain form, `set-word!` followed by value with two extensions:

1. it's possible to specify `Content-Type` by adding `path!` after value:

```
send-request/data server 'POST [
	#multi
	key0: "plain text without MIME type"
	key1: "plain text with MIME type" text/plain
	key2: {{"jsonkey": "json value"}} application/json
]
```

2. you can upload files also by having `file!` value:

```
send-request/data server 'POST [#multi upload-file: %some.file]
```

`send-request` tries to auto-detect wheter file is binary or text, you can
specify it manually by `text`, `bin` or `binary` postfix:

```
send-request/data server 'POST [
	#multi
	file1: %text-file.txt text
	file2: %picture.jpg bin
	file3: %song.mp3 binary
]
```

it's not possible to specify MIME type of file, it's either `text/plain` or
`application/octet-stream`.

### Refinements

#### /only

Return reply only without headers.

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

`send-request/data http://example.org 'POST #(name: "Albert Einstein" age: 140)`

POST request with multiple form data:

```
send-request/data http://example.org 'POST [
	#multi
	name: "Albert Einstein"
	age: 140 text/plain
	json: #(first-name: "Albert" last-name: "Einstein")
	image: %albert.jpg
]
```
