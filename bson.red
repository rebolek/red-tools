Red [
	Title: "BSON"
	Author: "Boleslav Březovský"
	Note: [
		"test31.bson fails - key is out of range. how to handle it?"
	]
]

path: %../libbson/tests/binary/


; Types:

; byte 	1 byte (8-bits)
; int32 	4 bytes (32-bit signed integer, two's complement)
; int64 	8 bytes (64-bit signed integer, two's complement)
; uint64 	8 bytes (64-bit unsigned integer)
; double 	8 bytes (64-bit IEEE 754-2008 binary floating point)
; decimal128 	16 bytes (128-bit IEEE 754-2008 decimal floating point)

; document 	::= 	int32 e_list "\x00" 	BSON Document. int32 is the total number of bytes comprising the document.

load-int: func [s e] [to integer! reverse copy/part s e]

debug?: true
debug: func [value] [if debug? [print value]]

bson: context [

	name=: value=: none

	length: 1
	byte: [skip]
	int32: [s: 4 byte e:]
	int64: [s: 8 byte e:]
	uint64: [s: 8 byte e:]
	double: [s: 8 byte e:]
	decimal128: [16 byte]

	null-byte: copy [#"^(00)"]
	string-byte: complement charset null-byte
	append null-byte [(print "null-byte")]

	document: [s: int32 e: (print ["doc length" load-int s e]) collect e-list null-byte]

	;e_list 	::= 	element e_list 	
	;	| 	"" 	

	e-list: [
		some [
			(print "check-elem>>")
			(name=: value=: none)
			p: (print mold p/1)
			not ahead null-byte
			(print "passed non-null-byte")
			element 
			(print "<<keep>>")
			; TODO: why is the check needed? 
			if (any [name= value=]) [
				keep (to string! name=) 
				keep (value=)
				(print ["elem:" name= value=])
			]
		]
	]

	probe-rule: [p: (print mold p)]

	element: [
		#"^(01)" (debug "float64") e-name double (value=: to float! reverse copy/part s e)     ; 64-bit binary FP
	|	#"^(02)" (debug "string") e-name string	(value=: to string! copy/part s e)   ; UTF-8 string
	|	#"^(03)" (debug "document") e-name keep (to string! name=) document   ; Embedded document
	|	#"^(04)" (debug "array") e-name keep (to string! name=) document   ; Array
	|	#"^(05)" (debug "binary") e-name binary    ; Binary data
	|	#"^(06)" (debug "undefined") e-name (value=: <DEPRECATED>) ; Deprecated
	|	#"^(07)" (debug "objectid") e-name s: 12 byte e: (value=: to integer! copy/part s e)   ; ObjectId
	|	#"^(08)" (debug "false") e-name #"^(00)" (value=: false)  ; Boolean "false"
	|	#"^(08)" (debug "true") e-name #"^(01)" (value=: true)  ; Boolean "true"
	|	#"^(09)" (debug "datetime") e-name (debug "dt1") int64 (probe "datatype+" value=: to date! probe load-int s e)     ; UTC datetime
	|	#"^(0A)" (debug "null") e-name (value=: none)            ; Null value
	|	#"^(0B)" (debug "regexp") e-name (regex=: copy []) cstring (append regex= to string! copy/part s e) cstring (append regex= to string! copy/part s e) (value=: regex=) ; Regular expression - The first cstring is the regex pattern, the second is the regex options string. ;Options are identified by characters, which must be stored in alphabetical order. Valid options are 'i' for case insensitive matching, 'm' ;for multiline matching, 'x' for verbose mode, 'l' to make \w, \W, etc. locale dependent, 's' for dotall mode ('.' matches everything), and ;'u' to make \w, \W, etc. match unicode.
	|	#"^(0C)" (debug "dbpointer") e-name string s: 12 byte e: (value=: probe to integer! copy/part s e) ; DBPointer — Deprecated
	|	#"^(0D)" (debug "jscode") e-name string (value=: to string! copy/part s e)    ; JavaScript code
	|	#"^(0E)" (debug "symbol") e-name string (value=: to string! copy/part s e)    ; Symbol. Deprecated
	|	#"^(10)" (debug "integer32") e-name int32 (print "val" value=: load-int s e) probe-rule      ; 32-bit integer
	|	#"^(11)" (debug "timestamp") e-name s: uint64 e: (print "val" value=: load-int s e)    ; Timestamp
	|	#"^(12)" (debug "integer64") e-name int64 (value=: load-int s e)     ; 64-bit integer
	|	#"^(13)" (debug "decimal128") e-name decimal128 ; 128-bit decimal floating point
	|	#"^(FF)" (debug "minkey") e-name            ; Min key
	|	#"^(7F)" (debug "maxkey") e-name            ; Max key
	]

	; TODO: where length is set, use that length in rule instead of SOME 

	e-name: [cstring (name=: copy/part s e)]              ; Key name
	string: [int32 (print ["length:" load-int s e] length: -1 + load-int s e) s: length byte e: null-byte] ; String - The int32 is the number bytes in the (byte*) + 1 (for the trailing '\x00'). The (byte*) is zero or more UTF-8 encoded characters.
	cstring: [s: some string-byte e: null-byte (print ["cstring" mold to string! copy/part s e])] ; Zero or more modified UTF-8 encoded characters followed by '\x00'. The (byte*) MUST NOT contain '\x00', hence it is not full UTF-8.
	binary: [int32 subtype s: some byte e: (value=: copy/part s e)] ; Binary - The int32 is the number of bytes in the (byte*).
	subtype: [
		#"^(00)"                   ; Generic binary subtype
	|	#"^(01)"                   ; Function
	|	#"^(02)"                   ; Binary (Old)
	|	#"^(03)"                   ; UUID (Old)
	|	#"^(04)"                   ; UUID
	|	#"^(05)"                   ; MD5
	|	#"^(80)"                   ; User defined
	]
	code-w-s: [int32 string document] ; Code w/ scope

	decode: func [data] [
		value=: none
		parse data document
	]

; === encoder =============================================================

	name: value: none

	keep-value: func [data] [
		append output probe to binary! probe reduce data
	]
	c-name: func [] [rejoin [form name #"^@"]]
	num: func [value] [reverse to binary! value]

	int-rule: [
		set name set-word! 
		set value integer!
		(keep-value [#"^(10)" c-name num value])
	]
	float-rule: [
		set name set-word! 
		set value float!
		(keep-value [#"^(01)" c-name num value])
	]
	logic-rule: [
		set name set-word! 
		set value logic!
		(keep-value [#"^(08)" c-name to char! make integer! value])
	]
	none-rule: [
		set name set-word! 
		none!
		(keep-value [#"^(0A)" c-name])
	]
	string-rule: [
		set name set-word!
		set value string!
		(keep-value [#"^(02)" c-name num 1 + length? value value #"^@"])
	]
	datetime-rule: [
		set name set-word!
		set value date!
		(keep-value [#"^(09)" c-name to binary! TODO: to-64-bit-integer-here! value])
	]
	regex-rule: [
		set name set-word!
		TODO:
	]
	code-rule: [
		TODO: "how to recognize js code?"
	]


	rules: [
		some [
			int-rule
		|	float-rule
		|	logic-rule
		|	none-rule
		|	string-rule
	;	|	datetime-rule
	;	|	regex-rule
	;	|	code-rule
		]
	]

	output: #{}

	init-output: does [
		clear output
		append output #{00000000}
	]

	encode: func [data] [
		init-output
		parse data rules
		head change/part output num length? output 4
	]
]