Red [
	Title: "GraphQL"
	Author: "Boleslav Březovský"
	Link: https://facebook.github.io/graphql/
]

graphql: context [

	output: []
	mark: none
	stack: []
	type!: none

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
	comment: [#"#" ws some comment-char ws]
	comment-char: difference source-char line-terminator
	; comma - already defined in Red
	token: [punctuator | name | int-value | float-value | string-value]
	ignored: [unicode-bom | whitespace | line-terminator | comment | comma]
	punctuator-chars: charset "!$():=@[]{|}"
	punctuator: [punctuator-chars | "..."]
	name: [start-name-char some name-char]
	start-name-char: charset [#"_" #"A" - #"Z" #"a" - #"z"] 
	name-char: union start-name-char charset [#"0" - #"9"]

	; query document
	document: [some definition]
	definition: [
		operation-definition 
	|	fragment-definition
	]
	operation-definition: [
		ws operation-type ws opt name opt variable-definitions opt directives selection-set
	|	selection-set
	]
	operation-type: ["query" | "mutation" | "subscription"]
	selection-set: [brace-start some selection brace-end]
	selection: [
		ws field ws
	|	ws fragment-spread ws
	|	ws inline-fragment ws
	]
	field: [
		opt [alias ws]
		name ws
		opt [arguments ws]
		opt [directives ws]
		opt selection-set
	]
	arguments: [paren-start argument ws any [ws argument ws] paren-end]
	argument: [name #":" ws value ws]
	alias: [name #":"]
	fragment-spread: ["..." ws fragment-name ws opt directives]
	fragment-definition: [
		"fragment" ws
		fragment-name ws
		type-condition ws
		opt directives ws
		selection-set
	]
	fragment-name: [ahead not "on" name]
	type-condition: ["on" ws named-type]
	inline-fragment: [
		"..." ws
		opt type-condition
		opt directives
		selection-set
	]

	; values and types
	value: [ ; wtf is const and ~const ?
		variable
	|	int-value (type!: 'integer!)
	|	float-value (type!: 'float!)
	|	string-value (type!: 'string!)
	|	boolean-value (type!: 'logic!)
	|	null-value (type!: 'none!)
	|	enum-value (type!: 'enum!)
	|	list-value (type!: 'list!)
	|	object-value (type!: 'object!)
	]
	int-value: [integer-part]
	integer-part: [
		opt negative-sign #"0"
	|	opt negative-sign non-zero-digit any digit
	]
	negative-sign: #"-"
	digit: charset [#"0" - #"9"]
	non-zero-digit: difference digit charset #"0"
	float-value: [
		integer-part fractional-part exponent-part
	|	integer-part fractional-part
	|	integer-part exponent-part
	]
	fractional-part: [#"." some digit]
	exponent-part: [exponent-indicator opt sign some digit]
	exponent-indicator: charset "eE"
	sign: charset "+-"
	boolean-value: ["true" | "false"]
	string-value: [{""} | #"^"" some string-char #"^""]
	string-char: [
		ahead not [#"^"" | #"\" | line-terminator] source-char
	|	{\u} escaped-unicode
	|	#"\" escaped-char
	]
	hex-char: charset [#"0" - #"9" #"a" - #"f" #"A" - #"F"]
	escaped-unicode: [4 hex-char]
	escaped-char: charset "^"\/bfnrt"
	null-value: "null"
	enum-value: [ahead not ["true" | "false" | "null"] name]
	list-value: [ ; NOTE: This is * rule
		; TODO: list= must be recursive
		"[]" (append mark [])
	|	[
			bracket-start
			(clear list=) 
			value* 
			(append list= load-value) 
			any [value* (append list= load-value)] 
			bracket-end
		]	
	]
	object-value: [
		brace-start brace-end
	|	brace-start object-field brace-end
	]
	object-field: [ws name #":" ws value any [ws name #":" ws value] ws]

	; variables
	variable: [#"$" name]
	variable-definitions: [paren-start some variable-definition paren-end]
	variable-definition: [variable #":" ws type opt default-value ws]
	default-value: [ws #"=" ws value ws]
	type: [named-type | list-type | non-null-type]
	named-type: [name]
	list-type: [bracket-start type bracket-end]
	non-null-type: [
		named-type #"!"
	|	list-type #"!"
	]
	directives: [some directive]
	directive: [#"@" name ws opt arguments]

	; active rules

	op-type=: name=: value=: alias=: type=:
		none
	list=: []

	; values and types
	value*: [
		ws
		copy value= [
			variable*
		|	int-value (type!: 'integer!)
		|	float-value (type!: 'float!)
		|	string-value (type!: 'string!)
		|	boolean-value (type!: 'logic!)
		|	null-value (type!: 'none!)
		|	enum-value (type!: 'enum!)
		|	list-value (type!: 'list!)
		|	object-value (type!: 'object!)
		]
		ws
	]

	name*: [copy name= name (name=: to word! name=)]
	keep-name*: [name* ws (append mark name=)]

	document*: [some definition*]
	definition*: [
		operation-definition* 
	|	fragment-definition*
	]
	operation-definition*: [
		[
			ws operation-type* ws 
			opt keep-name*
			opt variable-definitions*
			opt directives selection-set*
		]
	|	selection-set*
	]
	operation-type*: [copy op-type= ["query" | "mutation" | "subscription"] (append mark to word! op-type=)]
	selection-set*: [
		brace-start 
		(push-stack []) 
		some selection* 
		brace-end
		(mark: take/last stack)
	]
	selection*: [
		ws field* ws
	|	ws inline-fragment* ws
	|	ws fragment-spread* ws
	]
	field*: [
		opt [copy alias= alias ws (append mark to set-word! alias=)]
		keep-name*
		opt [arguments* ws]
		opt [directives ws]
		opt selection-set*
	]
	arguments*: [
		paren-start 
		(push-stack quote ())
		ws argument* ws 
		any [ws argument* ws] 
		paren-end
		(mark: take/last stack)
	]
	argument*: [
		name* #":" ws 
		value* ws 
		(repend mark [to set-word! name= load-value])
	]
	dots*: [
		"..." ws
		(append mark '...)
	]
	fragment-spread*: [
		dots*
		fragment-name* ws 
		opt directives
	]
	fragment-definition*: [
		"fragment" ws
		(append mark 'fragment)
		fragment-name* ws
		type-condition* ws
		opt directives ws
		selection-set*
	]
	fragment-name*: [
		ahead not "on" 
		copy name= name 
		(append mark load name=)
	]
	inline-fragment*: [
		dots*
		opt type-condition*
		opt directives
		selection-set*
	]
	type-condition*: [
		"on" ws (append mark 'on)
		keep-name*
	]
	; variables
	variable*: [ws #"$" name* (name=: to lit-word! name=)]
	variable-definitions*: [
		paren-start
		(push-stack quote ()) 
		some variable-definition* 
		paren-end
		(mark: take/last stack)
	]
	variable-definition*: [
		variable* #":" 
		type* 
		opt default-value*
		(repend mark [name= load-type])
		(if value= [append mark value=])
	]
	default-value*: [ws #"=" ws value* ws]
	type*: [ws copy type= [named-type | list-type | non-null-type]]
	named-type: [name]
	list-type: [bracket-start type bracket-end]
	non-null-type: [
		named-type #"!"
	|	list-type #"!"
	]
	directives: [some directive]
	directive: [#"@" name ws opt arguments]

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
			list!  [list=]
		] [value=]
	]

	load-type: does [
		select ["Boolean" logic!] type=
	]

	; === GraphQL parser =====================================================

	validate: func [
		"checks GraphQL validity"
		data
	] [
		parse data document
	]

	; === Decoder ============================================================

	decode: func [
		data
	] [
		clear output
		mark: output
		parse data document*
		all [
			1 = length? output
			block? first output
			output: first output
		]
		copy output
	]

	; === Encoder ============================================================

	encode: function [
		dialect [block!]
	] [
	{
	DIALECT DESCRIPTION
	===================

	name - 			word!
	selection set - block!
	arguments - 	paren!
	set variable - 	lit-word!
	get variable - 	get-word!
	}
		keep: func [value /tight] [
			value: either block? value [copy value] [reduce [value]]
			either tight [
				if equal? space last output [
					remove back tail output
				]
			] [
				append value space
			]
			append output rejoin value
		]

		output: make string! 1000
		value: none

		name-rule: [set value word! (keep [form value])]
		into-sel-set-rule: [
			ahead block! 
			(keep #"{") 
			into sel-set-rule 
			(keep #"}")
		]
		sel-set-rule: [
			some [
				into-sel-set-rule
			|	field-rule
			|	arguments-rule
			|	vals-rule
			]
		]
		field-rule: [name-rule]
		arguments-rule: [
			ahead paren! into [
				(keep #"(")
				some vals-rule
				(keep #")")
			]
		]
		vals-rule: [
			set value set-word! (keep [value #":"])
		|	set value lit-word! (keep [#"$" value #":"])
		|	set value get-word! (keep [#"$" value])
		|	set value block! (list: copy {} foreach val value [append list rejoin [mold val #","]] keep [#"[" list #"]"])
		|	into-sel-set-rule
		|	set value skip (keep [mold value])
		]
		parse dialect [
			some [
				name-rule
			|	sel-set-rule
			|	arguments-rule
			]
		]
		output
	]	
]
