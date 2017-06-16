Red [
	Title: "GraphQL"
	Author: "Boleslav Březovský"
	Link: https://facebook.github.io/graphql/
]

graphql: context [

	; === Rules  =============================================================

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
	selection-set: [ws #"{" ws some selection ws #"}" ws]
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
	arguments: [#"(" ws argument ws any [ws argument ws] ws #")" ws]
	argument: [name #":" ws value ws]
	alias: [name #":"]
	fragment-spread: ["..." ws fragment-name ws opt directives] ; starts with ..., wtf is it
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
	|	int-value
	|	float-value
	|	string-value
	|	boolean-value
	|	null-value
	|	enum-value
	|	list-value
	|	object-value
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
	list-value: [
		"[]"
	|	#"[" ws value any [ws value] ws #"]"	
	]
	object-value: [
		"{}"
	|	ws #"{" ws object-field ws #"}" ws
	]
	object-field: [ws name #":" ws value any [ws name #":" ws value] ws]

	; variables
	variable: [#"$" name]
	variable-definitions: [#"(" ws some variable-definition ws #")"]
	variable-definition: [variable #":" ws type opt default-value ws]
	default-value: [ws #"=" ws value ws]
	type: [named-type | list-type | non-null-type]
	named-type: [name]
	list-type: [#"[" ws type ws #"]"]
	non-null-type: [
		named-type #"!"
	|	list-type #"!"
	]
	directives: [some directive]
	directive: [#"@" name ws opt arguments]

	; active rules

	op-type=: name=: value=:
		none

	name*: [copy name= name]

	document*: [some definition*]
	definition*: [
		operation-definition* 
	|	fragment-definition*
	]
	operation-definition*: [
		[
			ws operation-type* ws 
			opt name*
			opt variable-definitions 
			opt directives selection-set*
			(print ["that was operation-definition*" mold op-type= mold name=])
		]
	|	selection-set*
	]
	operation-type*: [copy op-type= ["query" | "mutation" | "subscription"]]
	selection-set*: [ws #"{" (print "selection set") ws some selection* ws #"}" ws]
	selection*: [
		ws field* ws
	|	ws fragment-spread ws
	|	ws inline-fragment ws
	]
	field*: [
		opt [alias ws]
		name* ws (print ["field name: " name=])
		opt [arguments* ws]
		opt [directives ws]
		opt selection-set*
	]
	arguments*: [#"(" ws argument* ws any [ws argument* ws] ws #")" ws]
	argument*: [name* #":" ws value* ws (print ["argument" mold name= mold value=])]
	value*: [copy value= value]

	; === GraphQL parser =====================================================

	validate: func [
		"checks GraphQL validity"
		data
	] [
		parse data document
	]

	; === Decoder ============================================================

	decode: function [
		data
	] [
		; TODO
		output: clear []

		parse data document*

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
		keep: func [value] [append output rejoin append copy value space]

		output: make string! 1000
		value: none

		name-rule: [set value word! (keep [form value])]
		into-sel-set-rule: [
			ahead block! 
			(append output rejoin [#"{"]) 
			into sel-set-rule 
			(append output rejoin [#"}"])
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
				(append output #"(")
				some vals-rule
				(keep [#")"])
			]
		]
		vals-rule: [
			set value set-word! (keep [value #":"])
		|	set value lit-word! (keep [#"$" value #":"])
		|	set value get-word! (keep [#"$" value])
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
