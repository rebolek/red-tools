Red [
	Title: "HTTP Tools"
	File: %http-tools.red
	Author: "Boleslav Březovský"
	Description: "Collection of tools to make using HTTP easier"
	Date: 30-6-2020
	Resources: [
		base64url: RFC4648 https://tools.ietf.org/html/rfc4648
	]
	Problems: [{
	Rebol system/options/cgi problems:

	1) Capitalized `Content-Type`

	The only capitalized key. Should be changed to `content-type`.

	2) Everything is `string!`

	At least ports and IPs should be converted.

	3) Query decoding

	`query-string` for GET or `input` for POST provide raw data,
	but it would nice to have Red form of the data available, 
	regardless of the request method.
}
	]
	To-Do: [{
`parse-headers` should return raw map or everything converted,
`other-headers is stupid concept.
}
{SEND-REQUEST should add at least `Accept-Charset` automatically.}
{Multipart should check if boundary is not part of data}
	]
]

; --- support tools ----------------------------------------------------------

map-set: function [
	"Make map with reduce/no-set emulation"
	data
] [
	value: none
	parse data: copy data [
		some [
			change set value set-word! (reduce ['quote value])
		|	skip	
		]
	]
	make map! reduce data
]

cut-tail: function [
	"Remove value(s) from end of series"
	series
	/part
		length
] [
	unless part [length: 1]
	head remove/part skip tail series negate length length
]

enbase64url: func [
	"Encode a string into URL variant of BASE-64 encoding"
	value [string! binary!]
][
	value: enbase/base value 64
	if mark: find value #"=" [value: head clear mark]
	replace/all value #"/" #"_"
	replace/all value #"+" #"-"
	value
]

debase64url: func [
	"Decode a string from URL variant of BASE-64 encoding"
	value [string!]
	/json "Apply LOAD-JSON to result"
	/local padding
][
	; TODO: Add = when missing
	unless zero? padding: 4 - (length? value) // 4 [
		append/dup value #"=" padding
	]
	value: to string! debase value
	if json [value: load-json value]
	value
]

; --- server side tools ------------------------------------------------------

headers!: context [
	server-software: none
	server-name: none
	gateway-interface: none
	server-protocol: none
	server-port: none
	request-method: none
	path-info: none
	path-translated: none
	script-name: none
	query-string: none
	remote-host: none
	remote-addr: none
	auth-type: none
	remote-user: none
	remote-ident: none
	content-type: none
	content-length: none
	user-agent: none
	other-headers: none
]

parse-headers: func [
	query	[string!]
	/local headers raw key value cgi-key red-key
][
	headers: make headers! []
	raw: make map! 50
	key: value: none
	parse query [
		some [
			copy key to #"=" 
			skip
			copy value to newline
			skip
			(raw/:key: value)
		]
	]
	foreach [cgi-key red-key] [
		"HTTP_HOST" remote-host
		"HTTP_USER_AGENT" user-agent
		"SERVER_SOFTWARE" server-software
		"SERVER_NAME" server-name
		"SERVER_PORT" server-port
		"REMOTE_ADDR" remote-addr
		"SCRIPT_FILENAME" script-name
		"GATEWAY_INTERFACE" gateway-interface
		"SERVER_PROTOCOL" server-protocol
		"REQUEST_METHOD" request-method
		"QUERY_STRING" query-string
		"CONTENT_TYPE" Content-Type
	] [
		headers/:red-key: raw/:cgi-key
		raw/:cgi-key: none
	]
	headers/other-headers: raw
	headers
]

simple-parse-headers: func [
	query	[string!]
	/local headers raw key value cgi-key red-key
][
	headers: copy #()
	key: value: none
	parse query [
		some [
			copy key to #"=" 
			skip
			copy value to newline
			skip
			(headers/:key: value)
		]
	]
	headers
]

get-headers: func [
	"Parse HTTP headers and store them in HTTP-HEADERS map!"
	/local o os cmd
][
	os: os-info
	cmd: either find/match os/name "windows" ["set"] ["printenv"]
	call/wait/output cmd o: ""
	http-headers: simple-parse-headers o
]

process-input: func [
	"Return input data regardless of method"
	/only	"Do not convert the result"
	/local size result
][
	unless value? 'http-headers [get-headers]
	size: 2'097'152 ; NOTE: 2MiB preallocated for POST requests. Change if you need more
	switch select http-headers "REQUEST_METHOD" [
		"GET" [
			result: select http-headers "QUERY_STRING"
			unless only [
				result: make map! split result charset "=&"
			]
		]
		"POST" [
			read-stdin result: make binary! size size
			unless only [
				try [result: to string! result]
			]
		]
	]
	result
]

; get-headers

; --- client side tools ------------------------------------------------------

context [

	value: none
	result: none
	content-type: none
	multipart: none
	boundary: none

	url-rule: [
		set value [set-word! | word! | string!] (
			append result rejoin [form value #"="]
		)
		set value any-type! (
			append result either value [
				rejoin [to-pct-encoded form value #"&"]
			][#"&"]
		)
	]

	stringize: func [
		"Passes STRING! and rejoins BLOCK!"
		value [any-string! binary! block!]
	][
		if block? value [value: rejoin value]
		value
	]

	when: func [
		"Return value when COND is TRUE, otherwise return empty string"
		cond [logic!]
		value [any-type!]
	][
		either cond [stringize value][""]
	]
	keep: func [value][append multipart stringize value]
	keep-boundary: func [
		/end "Final boundary"
	][
		keep ["--" boundary when end "--" crlf]
	]
	keep-value: func [
		name
		value
		/type typename
		/local disps key val
	][
		if set-word? name [name: compose [name: (name)]]
		collect/into [
			foreach [key val] name [
				keep rejoin ["; " key {="} val #"^""]
			]
		] disps: copy ""
		keep [
			"Content-Disposition: "
;			either type ["attachement"]["form-data"]
			"form-data"
			disps crlf
			when type ["Content-Type: " typename crlf]
			crlf
		]
		keep value ; NOTE: must be separate, otherwise REJOIN will FORM it, this way we can pass binary!
		keep crlf
	]

	make-multipart: func [
		parts [block!]	"Multipart dialect"
		; if content is `file!`, content-type is switched to multipart/mixed
		/local bin? name value type mode filename part-key-value part-file
	][
		name: value: type: mode: filename: none
		multipart: copy #{}
		bin?: false
		boundary: make-nonce
		content-type: none

		part-key-value: [
			(type: none)
			set name set-word!
			set value [any-string! | number! | map!]
			opt set type path! (
				if map? value [
					value: to-json value
					type: 'application/json
				]
				keep-boundary
				either type [
					keep-value/type name value type
				][
					keep-value name value
				]
			)
		]
		part-file: [
			(mode: none)
			set name set-word!
			set filename file!
			opt set mode ['text | 'bin | 'binary] (
				keep-boundary
				switch/default mode [
					text [
						type: "text/plain"
						value: read filename
					]
					bin binary [
						bin?: true
						type: "application/octet-stream"
						value: read/binary filename
					]
				][
					value: read/binary filename
					type: either error? try [value: to string! value][
						bin?: true
						"application/octet-stream"
					][
						"text/plain"
					]
				]
				keep-value/type compose [name: (name) filename: (filename)] value type
			)
		]

		parse parts [
			some [
				part-file
			|	part-key-value
			]
		]
		content-type: rejoin ["multipart/form-data; boundary=" boundary]
		keep-boundary/end
		either bin? [multipart][to string! multipart] ; TODO: Is the conversion required? Probably not
	]

	#TODO {temporarily exposed for testing, make internal later}
	#TODO {is #multi really required?}
	set 'parse-data func [
		data	[block!]
	][
		content-type: "application/x-www-form-urlencoded"
		parse data [
			#JSON	copy value to end (
				content-type: "application/json"
				result: to-json value
			)
		|	#multi	copy value to end (result: make-multipart value)
		|	#Red	copy value to end (result: mold value) ; FIXME: needs proper content-type etc
		|	(result: copy {}) any url-rule (take/last result)
		]
		result
	]

	set 'make-url function [
		"Make URL from simple dialect"
		data
	] [
		; this is basically like to-url, with some exceptions:
		; WORD! - gets value
		; BLOCK! - treated as key/value storage of after "?" parameters
		value: none
		args: clear []
		link: make url! 80
		args-rule: [
			ahead block! into [
		; TODO: Use `url-rule` here
				any [
					set value set-word! (append args rejoin [form value #"="])
					set value [any-word! | any-string! | number!] (
						if word? value [value: get :value]
					;	append args rejoin [to-pct-encoded form value #"&"]
						append args rejoin [form value #"&"]
					)
				]
			]
		]
		parse append clear [] data [
			some [
				args-rule
			|	set value [set-word! | any-string! | refinement!] (append link dirize form value)
			|	set value [word! | path!] (append link dirize form get :value)	
			]
		]
		unless empty? args [
			change back tail link #"?"
			append link args
		]
		head remove back tail link	
	]

	set 'parse-cookies func [
		"Return map! of cookies"
		cookies [block!]
		/local result cookie name key value
	][
		result: make map! []
		foreach cookie cookies [
			parse cookie [
				copy name to #"=" skip
				copy value to [#";" | end]
				(result/:name: make map! compose ["value" (value)])
				#";" space some [
					copy key to #"=" skip
					copy value to [#";" | end]
					(result/:name/:key: value)
					[
						end break
					|	2 skip
					]
				]
			]
		]
		result
	]

	set 'make-cookies func [
		"Make cookies block! from map! of cookies"
		cookies [map!]
		/local key value
	][
		result: copy []
		foreach [name value] cookies [
			probe value
			cookie: form name ; form in case NAME is not string! already
			append cookie #"="
			append cookie select value "value"
			foreach [key value] value [
				unless "value" = form key [
					repend cookie ["; " key #"=" value]
				]
			]
			append result cookie
		]
		result
	]
	
	set 'make-request func [
		method	[word!]
		link	[url!]
		data	[string! block! map! object! none!]
		/with
			args [block! map!]
	][
		either with [
			send-request/data/verbose/with link method data args
		][
			send-request/data/verbose link method data
		]
	]

	set 'send-request function [
		"Send HTTP request. Useful for REST APIs"
		link 		[url!] 	"URL link"
		method 		[word!] "Method type (GET, POST, PUT, DELETE)"
		/only 		"Return only data without headers"
		/data 		"Data to send with request (auto-converted to proper encoding)"
			content [string! block! map! object! none!]
		/mold		"Do not auto-convert data and send tham as MOLDed Red values"
		/with 		"Headers to send with request"
			args	[block! map!]
		/auth 		"Authentication method and data"
			auth-type [word!] "Basic, Bearer, TODO: Digest"
			auth-data
		/raw 		"Return raw data and do not try to decode them"
		/verbose    "Print request informations"
		/debug		"Set debug words (see source for details)"
		/extern		content-type
	][
		if all [find [POST PUT] method not data][
			do make error! rejoin [method " method needs data. Use /data refinement."]
		]
		mold?: mold
		mold: :system/words/mold
		if verbose [
			print ["SEND-REQUEST to" link ", method:" method]
		]
		header: copy #() ; NOTE: CLEAR causes crash later!!! 
		if args [extend header args]
		if auth [
			if verbose [print [auth-type mold auth-data]]
			switch auth-type [
				Basic [
;					extend header compose [
;						Authorization: (rejoin [auth-type space enbase rejoin [first auth-data #":" second auth-data]])
;					]
					put header 'Authorization rejoin [
						auth-type space enbase rejoin [first auth-data #":" second auth-data]
					]
				]
				OAuth [
					; TODO: OAuth 1 (see Twitter API)
				]
				Bearer [
					; token passing for OAuth 2
;					extend header compose [
;						Authorization: (rejoin [auth-type space auth-data])
;					]
					put header 'Authorization rejoin [auth-type space auth-data]
				]
				Digest [
					<TODO>
				]
			]
		]
		; Process data
		case [
			mold? [content: system/words/mold/all content]
			all [method = 'GET not content][
				content-type: none
				content: clear ""
			]
			all [method = 'GET content][
				if map? content [content: body-of content]
				link: rejoin [link #"?" parse-data content]
				content: clear ""
			]
			block? content [
				content-type: "application/x-www-form-urlencoded"
				content: parse-data content
			]
			any [map? content object? content][
				; if you're passing map/object, it's safe to assume it should be send as JSON
				content-type: "application/json"
				content: to-json content
			]
			; TODO: string! Or is there anything needed for it?
		]
		; Make sure all values are strings
		if content-type [put header 'Content-Type content-type]
		body: body-of header
		forall body [body: next body body/1: form body/1]
		data: reduce [method body]
		append data content
		if verbose [
			print [
				"Link:" link newline
				"Header:" header newline
				"Data:" mold data newline
			]
		]
		if debug	[set 'req reduce [link data]]

		; -- send prepared request and process reply
		reply: write/binary/info link data
		if debug	[set 'raw-reply copy/deep reply]
		; Red strictly requires UTF-8 data, but we'll be bit more tolerant and allow anything
		if error? try [reply/3: to string! reply/3][reply/3: load-non-utf reply/3]
		if debug	[set 'string-reply copy/deep reply]
		if raw		[return reply]
		if verbose	[print ["Headers:" mold reply/2]]

; -- FIXME: Workaround for https://github.com/red/red/issues/4236
		headers: reply/2
		foreach [key value] headers [
			if all [
				block? value
				not equal? key "Set-Cookie"
			][
				headers/:key: unique value
				if 1 = length? headers/:key [
					headers/:key: first headers/:key
				]
				if find [Content-Type Content-Length] key [
					headers/:key: last headers/:key
				]
			]
		]
; -- end of workaround

		reply: map-set [
			code: reply/1
			headers: reply/2
			raw: reply/3
			data: mime-decoder reply/3 reply/2/Content-Type
		]
		if debug [set 'parsed-reply reply]
;		cookies: 
		either only [reply/data] [reply]
	]
]
;
; TODO: merge PARSE-CONTENT-TYPE and PARSE-PART as they basicaly share same
;		rules. PARSE-CONTENT-TYPE looks more standard compliant
;
parse-content-type: func [
	data [string! binary!]
	/local type subtype parameters tspecials token not-token value
][
	tspecials: charset {()<>@,;:\"/[]?=}
	; NOTE: `not-token` should also include control chars but I don't expect 
	;		them to be used
	not-token: union tspecials charset space 
	token: [
		#"^"" copy value to #"^""
	|	copy value some [not not-token skip]
	]

	parameters: copy #()
	parse data [
		copy type to #"/" skip
		copy subtype to [#";" | end]
		any [
			any space ; TODO: is it necessary?
			#";"
			any space
			token (key: value)
			#"="
			token (parameters/:key: value)
		]
	]
	reduce [type subtype parameters]
]

to-www-form: function [
	data
	/only "Ignore NONE values"
] [
	if any [map? data object? data] [data: body-of data]
	pattern: [key #"=" value #"&"]
	output: collect/into [
		foreach [key value] data [
			if any [not only all [only value]] [
				value: to-pct-encoded form value
				keep rejoin bind pattern 'key
			] 
		]
	] make string! 1000
	cut-tail/part output either only [length? form last pattern] [1]
]

load-www-form: func [
	string	[string!]
	/local result key value
][
	result: make map! []
	if equal? #"?" first string [string: next string]
	parse string [
		some [
			opt #"&"
			copy key to #"=" skip
			copy value to [#"&" | end] 
			(put result load-pct-encoded key load-pct-encoded value)
		]
	]
	result
]

split-multipart: func [
	series [binary!]
	delimiter [string!]
	/local result value
][
	result: copy []
	delimiter: to binary! delimiter
	parse series [
		"--"
		delimiter
		some [
			#{0D0A}
			copy value to "--"
			"--"
			delimiter
			(append result value)
		]
		"--"
	]
	result
]

parse-part: func [
	"Parse part of multipart data"
	part [binary!]
	/local crlf qt value
		fields field-rule field-name field-value 
		attrs attr-name attr-value
][
	crlf: #{0D0A}
	qt: #"^""
	fields: copy []
	field-rule: [
		(attrs: copy #())
		not crlf ; make sure we're not in VALUE already
		copy field-name to #":"
		#":" space
		[copy field-value to #";" | copy field-value to crlf]
		any [
			#";" space
			copy attr-name to #"=" #"="
			qt copy attr-value to qt qt
			(put attrs to string! attr-name to string! attr-value)
		]
		crlf
		(repend fields [to string! field-name to string! field-value attrs])
	]
	parse part [
		some field-rule
		crlf
		; NOTE: Instead of copying to CRLF, I copy to end and remove it
		;		as CRLF may be part of value, I guess
		copy value to end ; crlf crlf
		(take/last/part value 2)
		(append fields value)
	]
	fields
]

mime-decoder: function [
	string
	type
][
	if any [not string not type][return string]
	type: parse-content-type type
	case [
		all [type/1 = "application" type/2 = "json"][load-json string]
		all [type/1 = "application" type/2 = "x-www-form-urlencoded"][
			load-www-form string
		]
		type/1 = "text" [string]
		type/1 = "multipart" [
			boundary: select type/3 "boundary"
			collect [
				foreach part split-multipart string boundary [
					keep parse-part part
				]
			]
		]
	]
;	switch type [
;		"application/json" [load-json string]
;		"application/x-www-form-urlencoded" [load-www-form string]
;	;	"text/html" [www-form/decode string]
;		"text/html" [string]
;	]
]

make-nonce: function [] [
	nonce: enbase/base checksum form random/secure 2147483647 'SHA512 64
	remove-each char nonce [find "+/=" char]
	copy/part nonce 32
]

get-unix-timestamp: function [
	"Read UNIX timestamp from Internet"
] [
	date: none
	page: read http://www.unixtimestamp.com/
	parse page [
		thru "The Current Unix Timestamp"
		thru <h3 class="text-danger">
		copy date to <small>
	]
	to integer! date
]

; --- percent encoding -------------------------------------------------------


context [
	; RFC 3986 characters
	reserved-chars: union charset "!*'();:@&=+$,/?#[]" charset "%" ; RFCs are stupid
	unreserved-chars: charset [#"A" - #"Z" #"a" - #"z" #"0" - #"9" "-_.~"]
	set 'to-pct-encoded function [
		string [any-string!]
	] [
		value: none
		chars: unreserved-chars
		encode: func [value][head insert enbase/base form value 16 #"%"]
comment {
		rejoin head insert parse string [
			collect [
				some [
					keep some chars
				|	space keep #"+"	
				|	set value skip keep (head insert enbase/base form value 16 "%")
				]
			]
		] ""
}
		result: copy {}
		parse string [
			collect into result [
				some [
					set value reserved-chars keep (encode value)
				|	space keep ("%20")
				|	keep skip
				]
			]
		]
		result
	]

	set 'load-pct-encoded function [
		string [string!]
	] [
		to string! collect/into [
			parse string [
				some [
					#"+" (keep space) ; should be here? or add some switch?
				|	#"%" 
					copy value 2 skip (
						keep to integer! append value #"h"
					)
				|	set value skip (
						keep to integer! value
					)
				]
			]
		] make binary! 100
	]

	; Temporary function
	ansi-decode: function [
		string [string!]
	] [
		rejoin parse string [
			collect [
				some [
					#"+" keep space ; should be here?
				|	"%26%23" ; &#nnnn; encoding TODO: hexadecimal form
					copy value to "%3B" 3 skip keep (
						to char! to integer! value
					)
				|	#"%" 
					copy value 2 skip keep (
						to char! to integer! append value #"h"
					) 
				| 	keep skip
				]
			]
		]
	]
]

load-non-utf: func [
	data [binary!]
] [
	copy collect/into [forall data [keep to char! data/1]] {}
]
