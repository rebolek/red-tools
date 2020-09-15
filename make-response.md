# MAKE-RESPONSE

`make-response` is a Red function that creates HTTP response string from input
string or dialect. It can set status code and `Content-Type` header field
based on type of the input data.

## modes of operation

There are two basic modes of operation - automatic and dialected. Automatic
mode sets `Content-Type` based on type of data, while dialected mode offers
fine control over the HTTP response using simple dialect.

## Automatic mode

Automatic mode just sets `Content-Type` header field according to the type
of deta:

### string

When VALUE is a `string!`, Content-Type is determined by first character:

"<"			-	text/html
"{" or "["	-	application/json
else			text/plain

More types may be supported in the future.

### map and object

If VALUE is `map!` or `object!`, it's converted to JSON and Content-Type
is set accordingly.

## dialect

Dialect offers finer control over the HTTP response. It allows user to set
status code and various header fields.

### status code

Status code is optional. It consist of an `integer!` for a status code and
an optional `string!` for the reason message.

Examples:

```
make-response [200 "content"]

make-response [200 "OK" "content"]
```

### content type

Content type is optional and overrides auto-detection mechanism. It can be
either `word!` for predefined types or `path!` for other types. Predefined
types are:

- html - text/html
- text - text/plain
- json - application/json
- csv  - text/csv
- xml  - text/xml
- jpeg - image/jpeg
- png  - image/png

Other types may be supported in future.

If no type is set, dialected mode uses same autodetection mechanism as
automatic mode.

Examples:

```
make-response [json {{"key": "value"}}]

make-response [text/html {<html><body>hello world</body></html>}]

make-response [200 "hello"]
```

In the last example, `make-response` can detect that the string is content
and not areason message for the status code.

### content

Content is last value in dialect and is the only value that **MUST** be
present in the dialect block. It's type can be `string!` or `file!`.
If no `Content-Type` was set, auto-detection is used for `string!` content
and `application/octet-stream` type is used for `file!.`
