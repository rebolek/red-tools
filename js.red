Red [
	Title: "GraphQL"
	Author: "Boleslav Březovský"
	Link: https://facebook.github.io/graphql/
	To-Do: [
		"List! rule is not recursive"
	]
]

js: context [

	; various values

	null-value: none ; change this, if you do not want NONE in place of NULL

	output: []
	mark: none
	stack: []
	type!: none
	s: e: none

	op-type=: value=: type=: selection=: object=: list=: path=: paren=:
		none

	js-types: [
		integer! "Int" float! "Float" string! "String" logic! "Boolean" 
		none! "Null" enum! "Enum" list! "List" object! "Object"
	]
	red-types: reverse copy js-types

	; === Rules  =============================================================

	bracket-start: [ws #"[" ws]
	bracket-end: [ws #"]" ws] 
	brace-start: [ws #"{" ws]
	brace-end: [ws #"}" ws]
	paren-start: [ws #"(" ws]
	paren-end: [ws #")" ws]

	; source text
	source-char: charset reduce [tab cr lf #" " '- #"^(FFFF)"]
	unicode-bom: #"^(FEFF)"
	whitespace: charset reduce [space tab]
	ws: [any ignored]
	line-terminator: charset reduce [cr lf] ; [crlf | cr | lf]
	comment: ["//" ws some comment-char ws]
	comment-char: difference source-char line-terminator
	comma*: [ws comma ws]
	token: [punctuator | name | int-value | float-value | string-value]
	ignored: [unicode-bom | whitespace | line-terminator | comment]
	punctuator-chars: charset "!$():=@[]{|}"
	punctuator: [punctuator-chars | "..."]
	name*: [start-name-char any name-char]
	start-name-char: charset [#"_" #"A" - #"Z" #"a" - #"z"] 
	name-char: union start-name-char charset [#"0" - #"9"]

	; values and types
	value*: [
		ws
		[
		;	variable* (type!: 'variable!) keep (to get-word! copy/part s e)
			int-value* (type!: 'integer!) keep (load copy/part s e)
		|	float-value* (type!: 'float!) keep (load copy/part s e)
		|	boolean-value* (type!: 'logic!) keep (copy/part s e)
		|	string-value* (type!: 'string!) keep (copy/part s e)
		|	null-value* (type!: 'none!) keep (null-value)
	;	|	enum-value* (type!: 'enum!) (print "--type enum")
		|	list-value* (type!: 'list!) ; handled in list-value*
		|	object-value* (type!: 'object!)
		|	s: name* e: keep (print "name" probe to word! copy/part s e)
		]
		ws
	]
	int-value*: [s: integer-part e:]
	integer-part: [
		opt negative-sign #"0"
	|	opt negative-sign non-zero-digit any digit
	]
	negative-sign: #"-"
	digit: charset [#"0" - #"9"]
	non-zero-digit: difference digit charset #"0"
	
	float-value*: [
		s: [
			integer-part fractional-part exponent-part
		|	integer-part fractional-part
		|	integer-part exponent-part
		]
		e:
	]
	fractional-part: [#"." some digit]
	exponent-part: [exponent-indicator opt sign some digit]
	exponent-indicator: charset "eE"
	sign: charset "+-"

	boolean-value*: [s: ["true" | "false"] e:]

	string-value*: [#"^"" s: e: #"^"" | #"^"" s: some string-char e: #"^""]
	string-char: [
		ahead not [#"^"" | #"\" | line-terminator] source-char
	|	{\u} escaped-unicode
	|	#"\" escaped-char
	]
	hex-char: charset [#"0" - #"9" #"a" - #"f" #"A" - #"F"]
	escaped-unicode: [4 hex-char]
	escaped-char: charset "^"\/bfnrt"
	
	null-value*: "null"
	enum-value*: [ahead not ["true" | "false" | "null"] name]
	list-value*: [ ; NOTE: This is * rule
		; TODO: list= must be recursive
		"[]" keep ([])
	|	[
			bracket-start
			(print "list")
			collect set list=
			[
				value* 
				any [comma* value*]
			]
			bracket-end
			keep (list=)
		]	
	]
	object-value*: [
		brace-start brace-end keep (#())
	|	brace-start collect set object= object-fields keep (make map! object=) brace-end
	]
	object-fields: [
		object-field
		any object-field
		ws
	]
	object-field: [
		ws s: name* e: 
		#":" ws 
		keep (to set-word! copy/part s e)
		value* 
	]

	; query document

	semicolon*: [ws #";" ws]

	document*: [
		some [
			path*
		|	set-var*
		|	call-func*	
		|	value*
		]
	]

	set-var*: [
		ws "var" ws s: name* e: ws #"=" ws
		; TODO: set name and keep only when whole rule passed
		keep ('var) ; TODO: keep only
		keep (to set-word! copy/part s e)
		[
			[
				ws "new" ws 
				keep ('new) 
				s: name* e: ; type
			;	keep (to word! copy/part s e)
				value*
			]
		|	value*
		]
		opt semicolon*
	]

	call-func*: [
		s: name* e: 
		paren-start 
		keep (to word! copy/part s e)
		args* 
		paren-end
	]

	args*: [
		(paren=: make paren! [])
		collect into paren= [
			opt arg*
			any [comma* arg*]
			ws
		]
		keep (paren=)
	]

	arg*: [
	; TODO: move NAME to VALUE*
		s: name* e: keep (to word! copy/part s e)
	|	value*
	]

	path*: [
		(path=: make block! 10)
		s: name* e:
		some [
			#"." 
			(print "path")
			(append path= to word! copy/part s e)
			s: name* e:
		]
		(append path= to word! copy/part s e)
		keep (to path! path=)
	]
	
	; === Support ============================================================

	push-stack: func [
		value
	] [
		append/only mark copy value
		append/only stack tail mark
		mark: last mark
	]

	load-value: does [
		switch/default type! [
			integer! [load value=]
			string! [load value=]
			variable! [to get-word! head remove value=]
			list!  [list=]
		] [value=]
	]

	block-to-list: function [
		block
	] [
		list: copy {} 
		foreach value block [
			append list rejoin [mold value #","]
		] 
		remove back tail list
		rejoin [#"[" list #"]"]
	]
	map-to-obj: function [
		data
	] [
		obj: copy {} 
		foreach [key value] body-of data [
			repend obj [mold key space mold value #"," space]
		] 
		remove back tail obj
		rejoin [#"{" obj #"}"]
	]

	; === JS parser =====================================================

	validate: func [
		"checks GraphQL validity"
		data
	] [
		parse data document*
	]

	; === ;r ============================================================

	decode: func [
		data
	] [
		parse data [collect document*]
	]

	; === Encoder ============================================================

	encode: function [
		dialect [block!]
	] [
		print "TBD"
	]	
]