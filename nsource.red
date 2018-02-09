Red [
	Title: 		"Nsource - native source"
	Purpose:	"Print source for native functions"
	Author: 	"Boleslav Březovský"
	Date: 		"9-2-2018"
]

indent: func [
	"(Un)indent text by tab"
	string 	[string!]	"Text to (un)indent"
	value 	[integer!] 	"Positive vales indent, negative unindent"
	/space 	"Use spaces instead of tabs (default is 4)"
	/size	"Tab size in spaces"
		sz 	[integer!]
	; NOTE: Unindent automaticaly detects tabs/spaces, but for different size than 4,
	;		/size refinement must be used (TODO: autodetect space size?)
	;
	;		Zero value does automatic unindentation based on first line
] [
	out: make string! length? string
	indent?: positive? value 					; indent or unindent?
	ending?: equal? newline back tail string 	; is there newline on end?
	unless size [sz: 4]
	tab: either any [space not positive? value] [append/dup copy "" #" " sz] [#"^-"]
	if zero? value [
		parse string [
			; NOTE: The rule will accept comination of tabs and spaces.
			;		Probably not a good thing, maybe it can be detected somehow.
			some [
				tab 	(value: value - 1)
			|	#"^-"	(value: value - 1)
			|	break
			]
			to end
		]
	]
	data: split string newline
	foreach line data [
		loop absolute value [
			case [
				; indent
				indent? [insert line tab]
				; unindent
				all [not indent? equal? first line #"^-"] [remove line]
				all [not indent? equal? copy/part line sz tab] [remove/part line sz]
			]
		]
		; process output
		append out line
		append out newline
	]
	unless ending? [remove back tail out] ; there wasn't newline on end, remove current
	out
]

entab: function [
	"Replace spaces at line start with tabs (default size is 4)"
	string 	[string!]
	/size "Number of spaces per tab"
		sz 	[integer!]
] [
	sz: max 1 any [sz 4]
	spaces: append/dup clear "" #" " sz
	sz: sz - 1
	parse string [some [some [not spaces change 1 sz space "" | change spaces tab] thru newline]]
	string
]

detab: function [
	"Replace tabs at line start with spaces (default size is 4)"
	string 	[string!]
	/size "Number of spaces per tab"
		sz 	[integer!]
] [
	sz: max 1 any [sz 4]
	spaces: append/dup clear "" #" " sz
	sz: sz - 1
	parse string [some [some [spaces | change [0 sz space tab] spaces] thru newline]]
	string
]

match-bracket: function [
	string [string!]
] [
	mark: none
	level: 0
	slevel: 0
	subrule: [fail]
	string-char: complement charset [#"^""]
	mstring-char: complement charset [#"{" #"}"]
	string-rule: [
		#"^""
		some [
			{^^"}
		|	[#"^"" break]
		|	string-char
		]
	]
	mstring-rule: [ ; multiline string
		#"{" (slevel: slevel + 1)
		some [
			#"{" (slevel: slevel + 1)
		|	[#"}" (slevel: slevel - 1 subrule: either zero? slevel [[break]] [[fail]]) subrule]
		|	mstring-char
		]
	]
	parse string [
		some [
			{#"["}		; ignore char!
		|	{#"]"}		; ignore char!
		|	#"[" (level: level + 1)
		|	#"]" (level: level - 1 subrule: either zero? level [[break]] [[fail]]) subrule
		|	string-rule
		|	mstring-rule
		|	skip
		]
		mark:
	]
	mark
]

nsource: func [
	'word
] [
	if native? get word [
		runtime-link: https://raw.githubusercontent.com/red/red/master/runtime/natives.reds
		env-link: https://raw.githubusercontent.com/red/red/master/environment/natives.red
		
		; Red/System source
		sources: read runtime-link
		run-word: append form word #"*"
		src: next find/reverse find sources run-word newline 	; find source and go back to line start
		spec: match-bracket find src #"[" 						; skip spec
		end: match-bracket find spec #"[" 						; skip body
		src: copy/part src end 									; copy func source

		; Red header
		headers: read env-link
		hdr: find headers head append form word #":"
		end: back match-bracket spec: next find hdr #"["		; get spec
		spec: copy/part next spec end 							; copy func source
		if equal? newline spec/1 [remove spec]


		; output
		print [
			uppercase form word "is native! so source is not available." newline
			newline
			"Here is latest version of Red/System source code" newline
			"which may or may not be same version as you are using" newline
			newline
			"Native specs:" newline
			newline
			indent spec 0
			newline
			"Native Red/System source:" newline
			newline
			indent src 0
			newline 
		]
	]
]