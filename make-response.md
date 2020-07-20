#MAKE-RESPONSE

`make-response` is a Red function that creates HTTP response string from input
string or dialect. Currently it adds `Content-Type` header based on type of
the input data.

##string

When VALUE is a `string!`, Content-Type is determined by first character:

"<"			-	text/html
"{" or "["	-	application/json
else			text/plain

More types may be supported in the future

##dialect

Dialect may start with Content-Type. That can be either `word!` for
predefined types or `path!` for other types. Predefined types are:

html	-	text/html
text	-	text/plain
json	-	text/json

Other types may be supported in future.

If no type is set, default Content-Type is "text/plain".

After type are reply data as `string!`

##map and object

If VALUE is `map!` or `object!`, it's converted to JSON and Content-Type
is set accordingly.
