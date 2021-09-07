Red [
	Title: "GraphQL"
	Author: "Boleslav Březovský"
	Link: https://facebook.github.io/graphql/
	To-Do: [
		"List! rule is not recursive"
		"block-strings are missing"
		"It should do type conversion but doesn’t"
	]
]

graphql: context [

	; various values

	null-value: none ; change this, if you do not want NONE in place of NULL

	output: []
	mark: none
	stack: []
	type!: none
	s: e: none

	op-type=: value=: type=: selection=: object=: list=:
		none

	graphql-types: [
		integer! "Int" float! "Float" string! "String" logic! "Boolean" 
		none! "Null" enum! "Enum" list! "List" object! "Object"
	]
	red-types: reverse copy graphql-types

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
	name: [start-name-char any name-char]
	start-name-char: charset [#"_" #"A" - #"Z" #"a" - #"z"] 
	name-char: union start-name-char charset [#"0" - #"9"]

	; values and types
	value*: [
		ws
		[
			variable* (type!: 'variable!) keep (to get-word! copy/part s e)
		|	int-value* (type!: 'integer!) keep (load copy/part s e)
		|	float-value* (type!: 'float!) keep (load copy/part s e)
		|	boolean-value* (type!: 'logic!) keep (copy/part s e)
		|	string-value* (type!: 'string!) keep (copy/part s e)
		|	null-value* (type!: 'none!) keep (null-value)
		|	enum-value* (type!: 'enum!) (print "--type enum")
		|	list-value* (type!: 'list!) ; handled in list-value*
		|	object-value* (type!: 'object!)
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
			collect set list=
			[
				value* 
				any value*
			]
			bracket-end
			keep (list=)
		]	
	]
	object-value*: [
		brace-start brace-end keep (#())
	|	brace-start collect set object= [object-field] keep (make map! object=) brace-end
	]
	object-field: [
		ws s: name* e: #":" ws 
		keep (to set-word! copy/part s e)
		value* 
		any [
			ws s: name* e: #":" ws
			keep (to set-word! copy/part s e)
			value*
		] 
		ws
	]

	name*: [start-name-char any name-char]
	; query document
	document*: [some definition*]
	definition*: [
		operation-definition* 
	|	fragment-definition*
	]
	operation-definition*: [
		[
			ws operation-type* ws 
			opt [s: name* e: keep (to word! copy/part s e)]
			opt variable-definitions*
			opt directives* selection-set*
		]
	|	selection-set*
	]
	operation-type*: [
		copy op-type= ["query" | "mutation" | "subscription"]
		keep (to word! op-type=)
	]
	selection-set*: [
		brace-start
		collect set selection=
		[some selection*] 
		keep (selection=)
		brace-end
	]
	selection*: [
		ws field* ws
	|	ws fragment-spread* ws
	|	ws inline-fragment* ws
	]
	alias*: [ws s: name e: #":" ws keep (to set-word! copy/part s e)]
	field*: [
		opt alias*
		s: name* e: keep (to word! copy/part s e)
		opt [arguments* ws]
		opt [directives* ws]
		opt selection-set*
	]
	; arguments
	arguments*: [
		paren-start
		collect set list= [
			ws argument* ws
			any [ws argument* ws] 
			paren-end
		]
		keep (to paren! list=)
	]
	argument*: [
		ws s: name* #":" e: ws keep (to set-word! copy/part s e)
		value* ws
	]
	dots*: [
		"..." ws
	]
	fragment-spread*: [
		dots*
		s: fragment-name* e: ws 
		keep ('...)
		keep (to word! copy/part s e)
		opt directives*
	]
	fragment-definition*: [
		"fragment" ws
		keep ('fragment)
		s: fragment-name* e: ws
		keep (to word! copy/part s e)
		type-condition* ws
		opt directives* ws
		selection-set*
	]
	fragment-name*: [
		ahead not "on" 
		name
	]
	inline-fragment*: [
		; NOTE: This rue is tested after fragment-spread*
		;		so keeping dots before checking rest of rule
		;		should probably won't calse troubles
		dots*
		keep ('...)
		opt type-condition*
		opt directives*
		selection-set*
	]
	type-condition*: [
		"on" ws 
		keep ('on)
		s: name* e:
		keep (to word! copy/part s e)
	]
	; variables
	variable*: [
		ws #"$" 
		s: name* e:
	]
	variable-definitions*: [
		paren-start
		collect set list=
		some variable-definition*
		paren-end
		keep (to paren! list=)
	]
	variable-definition*: [
		variable* #":" 
		keep (to lit-word! copy/part s e)
		type* 
		opt default-value*
	]
	default-value*: [ws #"=" ws value* ws]
	type*: [ws copy type= [named-type | list-type | non-null-type]]
	named-type: [s: name e: keep (to word! copy/part s e)]
	list-type: [bracket-start type bracket-end]
	non-null-type: [
		named-type #"!"
	|	list-type #"!"
	]
	directives*: [some directive*]
	directive*: [
		ws s: #"@" name* e: ws 
		keep (to email! copy/part s e)
		opt arguments*
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

	; === GraphQL minifier ==================================================

	minify: function [
		string
	] [
		ws: charset " ^-^/"
		delimiter: charset "[](){}"
		string: copy string ; NOTE: copy or not to copy
		parse string [
			opt [remove some ws]
			some [
				remove [#"#" thru newline]
			|	{"""} thru {"""}
			|	#"^"" thru #"^""
			|	change comma #" " opt [remove some ws]
			|	"..." opt [remove some ws]
			|	delimiter
				opt [remove comma]
				mark:
				some ws
				end:
				(remove/part mark end)
				:mark
			|	mark:
				some ws
				delimiter
				end:
				(remove/part mark back end)
				:mark
			|	change [some ws] #" "
			|	skip
			]
		]
		string
	]

	; === GraphQL parser =====================================================

	validate: func [
		"checks GraphQL validity"
		data
		/local valid?
	] [
		parse data [
			collect document*
			(valid?: true)
		]
		valid?
	]

	; === Decoder ============================================================

	decode: func [
		data
	] [
	;	mark: clear output
		parse data [collect document*]
	;	all [
	;		1 = length? output
	;		block? first output
	;		output: first output
	;	]
	;	copy output
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
		value: name: type: none
		stack: clear []

		push: [(append stack value)]
		pop: [(take/last value)]

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
		variable-rule: [
			(value: none)
			set name lit-word!
			set type skip
			; default value
			opt set value
			(keep [#"$" name #":" space])
		;	(keep [select graphql-types type space])
			(keep [type space])
			(if value [keep [#"=" space value]])
		]
		vals-rule: [
			set value set-word! (keep [value #":"])
		|	variable-rule
		|	set value get-word! (keep [#"$" value])
		|	set value block! (keep block-to-list value)
		|	into-sel-set-rule
		|	set value map! (keep map-to-obj value)
		|	set value skip (keep [mold value])
		]
		parse dialect [
			some [
				name-rule
			|	sel-set-rule
			|	arguments-rule
			]
		]
		minify output
	;	output
	]	
]

