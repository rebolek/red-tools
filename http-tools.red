Red [
	Title: "HTTP Tools"
	File: %http-tools.red
	Author: "Boleslav Březovský"
	Description: "Collection of tools to make using HTTP easier"
	Date: "10-4-2017"
	Problems: [
{
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
	To-Do: [
{
	ENCODE and DECODE functions.

	ENCODE data type
	DECODE data type

	Definition:

	<name> CODEC <definition> ; (infix func ;)

	example:

	'JSON codec [
		some: vars
		encode: ...
		decode: ...
	]

}
	]
]

do %json.red

; --- support tools ----------------------------------------------------------

map: function [
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

parse-headers: func [query] [
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
					append args rejoin [value #"&"]
				)
			]
		]
	]
	parse append clear [] data [
		some [
			args-rule
		|	set value [set-word! | file! | url! | refinement!] (append link dirize form value)
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
	]
	header: copy #() ; NOTE: CLEAR causes crash later!!! 
	if with [extend header args]
	if auth [
		switch auth-type [
			Basic [
				Authorization: (rejoin [auth-type space enbase rejoin [first auth-data #":" second auth-data]])
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
	data: reduce [method body-of header]
;	if content [append data content]
	unless content [content: ""]
	append data content
	if verbose [
		print [
			"Link:" link newline
			"Data:" mold data newline
			"print here"
		]
	]
	reply: write/info link data
	set 'raw-reply reply
	if raw [return reply]
	type: first split reply/2/Content-Type #";"
	if verbose [
		print ["Return type:" type]
	]
	reply: map [
		code: reply/1
		headers: reply/2
		raw: reply/3
		data: mime-decoder reply/3 type
	]
	either only [reply/data] [reply]
]

www-form: object [
	encode: function [
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
		cut-tail/part output either only [length? form last pattern] [2]
	]
	decode: function [
		string
	] [
		if empty? string [return none]
		data: split string charset "=&"
		forall data [data/1: percent/decode data/1]
		make map! data
	]
]

mime-decoder: function [
	string
	type
] [
	switch type [
		"application/json" [json/decode string]
		"application/x-www-form-urlencoded" [www-form/decode string]
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


percent: context [
	; RFC 3986 characters
	reserved-chars: union charset "!*'();:@&=+$,/?#[]" charset "%" ; RFCs are stupid
	unreserved-chars: charset [#"A" - #"Z" #"a" - #"z" #"0" - #"9" "-_.~"]
	encode: function [
		string [string!]
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

	decode: function [
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