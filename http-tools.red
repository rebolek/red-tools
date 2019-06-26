Red [
	Title: "HTTP Tools"
	File: %http-tools.red
	Author: "Boleslav Březovský"
	Description: "Collection of tools to make using HTTP easier"
	Date: "10-4-2017"
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
{/WITH should convert args into query for GET requests}
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

get-headers: func [/local o] [
	call/wait/output "printenv" o: ""
	http-headers: parse-headers o	
]

get-headers

; --- client side tools ------------------------------------------------------

make-url: function [
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
			any [
				set value set-word! (append args rejoin [form value #"="])
				set value [any-word! | any-string! | number!] (
					if word? value [value: get :value]
					append args rejoin [to-pct-encoded form value #"&"]
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

send-request: function [
	"Send HTTP request. Useful for REST APIs"
	link 		[url!] 	"URL link"
	method 		[word!] "Method type (GET, POST, PUT, DELETE)"
	/only 		"Return only data without headers"
	/data 		"Use with POST and other methods"
		content
	/with 		"Headers to send with request"
		args
	/auth 		"Authentication method and data"
		auth-type [word!]
		auth-data
	/raw 		"Return raw data and do not try to decode them"
	/verbose    "Print request informations"
] [
	if verbose [
		print ["SEND-REQUEST to" link ", method:" method]
		print ["header:" mold args]
	]
	header: copy #() ; NOTE: CLEAR causes crash later!!! 
	if args [extend header args]
	if auth [
		if verbose [print [auth-type mold auth-data]]
		switch auth-type [
			Basic [
				extend header compose [
					Authorization: (rejoin [auth-type space enbase rejoin [first auth-data #":" second auth-data]])
				]
			]
			OAuth [
				; TODO: OAuth 1 (see Twitter API)
			]
			Bearer [
				; token passing for OAuth 2
				extend header compose [
					Authorization: (rejoin [auth-type space auth-data])
				]
			]
		]
	]
	; Make sure all values are strings
	body: body-of header
	forall body [body: next body body/1: form body/1]
	data: reduce [method body]
	if any [
		not content
		method = 'GET
	] [content: clear ""]
	append data content
	if verbose [
		print [
			"Link:" link newline
			"Data:" mold data newline
		]
	]
	set 'req reduce [link data]
	reply: write/binary/info link data
	set 'raw-reply copy/deep reply
	; Red strictly requires UTF-8 data, but we'll be bit more tolerant and allow anything
	if error? try [reply/3: to string! reply/3][reply/3: load-non-utf reply/3]
	set 'raw-reply  copy/deep reply
	if raw [return reply]
	type: first split reply/2/Content-Type #";"
	if verbose [
		print ["Return type:" type]
	]
	reply: map-set [
		code: reply/1
		headers: reply/2
		raw: reply/3
		data: mime-decoder reply/3 type
	]
	either only [reply/data] [reply]
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
			copy key to #"=" skip
			copy value to [#"&" | end]
			(put result load-pct-encoded key load-pct-encoded value)
		]
	]
	result
]

mime-decoder: function [
	string
	type
] [
	unless string [return string]
	switch type [
		"application/json" [load-json string]
		"application/x-www-form-urlencoded" [load-www-form string]
	;	"text/html" [www-form/decode string]
		"text/html" [string]
	]
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
		rejoin head insert parse string [
			collect [
				some [
					keep some chars
				|	space keep #"+"	
				|	set value skip keep (head insert enbase/base form value 16 "%")
				]
			]
		] ""
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
