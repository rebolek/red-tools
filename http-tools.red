Red [
	Title: "HTTP Tools"
	File: %http-tools.red
	Author: "Boleslav Březovský"
	Description: "Collection of tools to make using HTTP easier"
	Date: "10-4-2017"
]

do %json.red

map: function [
	"Make map with reduce/no-set emulation"
	data
] [
	value: none
	parse data [
		some [
			change set value set-word! (reduce ['quote value])
		|	skip	
		]
	]
	make map! reduce data
]


make-url: function [
	"Make URL from simple dialect"
	data
] [
	value: none
	args: clear []
	link: make url! 80
	args-rule: [
		ahead block! into [
			some [
				set value set-word! (append args rejoin [form value #"="])
				set value [word! | string! | integer!] (
					if word? value [value: get :value]
					append args rejoin [value #"&"]
				)
			]
		]
	]
	parse append clear [] data [
		some [
			args-rule
		|	set value [set-word! | file! | url! ] (append link dirize form value)
		|	set value word! (append link dirize form get :value)	
		]
	]
	unless empty? args [
		change back tail link #"?"
		append link args
	]
	head remove back tail link	
]

send-request: function [
	link 
	method
	/data 		"Use with POST and other methods"
		content
	/with 
		args
	/auth
		auth-type [word!]
		auth-data
] [
	header: clear #()
	if with [extend header args]
	if auth [
		switch auth-type [
			Basic [
				Authorization: (rejoin [auth-type space enbase rejoin [first auth-data #":" second auth-data]])
			]
			OAuth [
				; TODO: Add OAuth (see Twitter API)
			]
			Bearer [
				; token passing for Gitter
				extend header compose [
					Authorization: (rejoin [auth-type space auth-data])
				]
			]
		]
	]
	data: reduce [method body-of header]
	if content [append data content]
	reply: write/info link data
	type: first split reply/2/Content-Type #";"
	map [
		code: reply/1
		headers: reply/2
		raw: reply/3
; TODO: decode data based on reply/2/Content-Type		
;		data: (www-form/decode reply/3 type)
		data: json/decode reply/3
	]
]

www-form: object [
	encode: function [
		data
		/only "Ignore NONE values"
		/with 
			pattern
	] [
		if any [map? data object? data] [data: body-of data]
		print mold data
		unless with [pattern: [key {="} value {", }]]
		output: collect/into [
			foreach [key value] data [
				if any [not only all [only value]] [
					keep rejoin bind pattern 'key
				] 
			]
		] make string! 1000
		cut-tail/part output either with [length? form last pattern] [2]
	]
	decode: function [
		text
		type
	] [
		; TODO: just www-form decoder should be here
		;		there should be another function on top of this (MIME-DECODER)
		switch type [
			"application/json" [text]
			"application/x-www-form-urlencoded" [
				text: make map! split text charset "=&"
			]
			"text/html" [
				text: make map! split text charset "=&"
			]
		]
		text
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

url-encode: function [
	text [any-string!]
] [
	value: none
	chars: charset ["!'*,-.~_" #"0" - #"9" #"A" - #"Z" #"a" - #"z"]
	rejoin head insert parse text [
		collect [
			some [
				keep some chars
			|	space keep #"+"	
			|	set value skip keep (head insert enbase/base form value 16 %"%")
			]
		]
	] ""
]