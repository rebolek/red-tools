Red[]

hex-charset: func [
	data
	/local ws hex hex-number range stack output
][
	ws: reduce ['any charset " ^-^/"]
	hex: charset "abcdefABCDEF0123456789"
	hex-number: [
		"#x" copy value 1 6 hex
		(append stack probe value)
	]
	range: [
		#"[" hex-number p: #"-" p1: hex-number #"]"
		(
			probe stack
			repend output [
				to char! to integer! to issue! stack/1
				'-
				to char! to integer! to issue! stack/2
			]
			clear stack
		)
	]
	stack: clear []
	output: clear []
	parse data [
		some [
			range any [ws #"|" ws range]
		]
	]
	charset output
]

#TODO {ISSUE-CHARSET, like HEX-CHARSET, but will take block (needs adding spaces)} 

repl: [
	enclose [value closure][closure value closure]
]

make-rule: func [replacements /local output name spec body][
	output: copy []
	foreach [name spec body] replacements [
		body: copy body
		until [
			change/only/part body to path! reduce ['args index? find probe spec probe body/1] 1
			tail? body: next body
		]
		probe body: head body
		repend output [
			'change
			reduce [to lit-word! name 'copy 'args (length? spec) 'skip]
			to paren! reduce ['reduce body]
		]
	]
	append output [| skip]
	reduce ['some output]
]

compile-rule: func [value replacements][
	value: copy value
	parse value make-rule replacements
	value
]

xml: context [

	sq: #"'"
	dq: #"^""
	caret: #"^^"
	lower-letter: charset [#"a" - #"z"]
	upper-letter: charset [#"A" - #"Z"]
	digit: charset [#"0" - #"9"]
	letter: union lower-letter upper-letter
	alphanum: union letter digit

	; -- Document
	document: [
		prolog
		element
		not any Char any Misc
		RestrictedChar
		any Char
	]

	; -- Character Range
	Char: hex-charset {[#x1-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF]}
	RestrictedChar: hex-charset {[#x1-#x8] | [#xB-#xC] | [#xE-#x1F] | [#x7F-#x84] | [#x86-#x9F]}

	;TODO: compatibility characters

	; -- White Space
	S: charset reduce [space tab cr lf]
	S?: [opt S]

	; -- Names and Tokens
	NameStartChar:
	name-start-char: charset [
		":_" #"a" - #"z" #"A" - #"Z" #"0" #"^(C0)" - #"^(D6)" #"^(D8)" - #"^(F6)" 
		#"^(F8)" - #"^(02FF)" #"^(0370)" - #"^(037D)" #"^(037F)" - #"^(1FFF)"
		#"^(200C)" - #"^(200D)" #"^(2070)" - #"^(218F)" #"^(2C00)" - #"^(2FEF)"
		#"^(3001)" - #"^(D7FF)" #"^(F900)" - #"^(FDCF)" #"^(FDF0)" - #"^(FFFD)"
		#"^(010000)" - #"^(0EFFFF)"
	]
	NameChar:
	name-char: union name-start-char charset [
		"-." #"0" - #"9" #"^(B7)" #"^(0300)" - #"^(036F)" #"^(203F)" - #"^(2040)"
	]
	Name:
	name: [name-start-char any name-char]
	Names: [Name any [space Name]]
	Nmtoken: [some NameChar]
	Nmtokens: [Nmtoken any [space Nmtoken]]

	;-- Literals
	ent-dchars: charset {^^%&"}
	ent-schars: charset {^^%&'}
	EntityValue: [
		dq any [ent-schars | PEReference | Reference] dq
	|	sq any [ent-schars | PEReference | Reference] sq
	]
	att-dchars: charset {^^<&"}
	att-schars: charset {^^<&'}
	AttValue: [
		dq any [att-dchars | reference] dq
	|	sq any [att-schars | reference] sq
	]
	SystemLiteral: [
		dq any [#"^^" | dq] dq
	|	sq any [#"^^" | sq] sq
	]
	PubidLiteral: [
		dq any PubidChar dq
	|	sq any [not sq PubidChar] sq
	]
	PubidChar: charset reduce [space cr lf #"a" '- #"z" #"A" '- #"Z" {-'()+,./:=?;!*#@$_%}]

	; -- Character Data
	cd-chars: charset "^^<&"
	CharData: [not ["]]>" any cd-chars] any cd-chars]

	; -- Comment
	Comment: [
		"<!--"
		some [
			[not #"-" Char] 
		|	[#"-" not #"-" Char]
		]
		"-->"
	]

	; -- Processing Instructions
	PI: [
		"<?"
		PITarget
		opt [
			S not [any Char "?>" any Char] any Char
		]
		"?>"
	]
	PITarget-chars: charset "xXmMlL"
	PITarget: [not PITarget-chars Name]

	; -- CDATA Sections
	CDSect: [CDStart CData CDend]
	CDStart: "<![CDATA["
	CData: [any [not "]]>" Char]]
	CDend: "]]>"

	; -- Prolog
	prolog: [
		XMLDecl
		any Misc
		opt [doctypedecl any Misc]
	]
	XMLDecl: [
		{<?xml} VersionInfo opt EncodingDecl opt SDDecl opt S {?>}
	]
	VersionInfo: [
		S "version" Eq [sq VersionNum sq | dq VersionNum dq]
	]
	Eq: [opt S #"=" opt S]
	VersionNum: "1.1"
	Misc: [Comment | PI | S]

	; -- Document Type Definition
	doctypedecl: [
		"<!DOCTYPE" S Name
		opt [S ExternalID]
		opt S
		opt [#"[" intSubset #"]" opt S]
		#">"
	]
	DeclSep: [PEReference | S]
	intSubset: [any [markupdecl | DeclSep]]
	markupdecl: [elementdecl | AttlistDecl | EntityDecl | NotationDecl | PI | Comment]

	; -- External Subset
	extSubset: [opt TextDecl extSubsetDecl]
	extSubsetDecl: [any [markupdecl | conditionalSect | DeclSep]]

	; -- Standalone Document Declaration
	SDDecl: [
		some space
		"standalone"
		Eq
		[sq ["yes" | "no"] sq | dq ["yes" | "no"] dq]
	]

	; -- Elements
	element: [
		EmptyElemTag
	|	STag content ETag
	]
	STag: [#"<" Name any [S Attribute] opt S #">"]
	Attribute: [Name Eq AttValue]
	ETag: ["</" Name opt S #">"]
	content: [opt CharData any [[element | Reference | CDSect | PI | Comment] opt CharData]]
	EmptyElemTag: [#"<" Name any [S Attribute] opt S "/>"]
	elementdecl: ["<!ELEMENT" S Name S contentspec opt S #">"]
	contentspec: ["EMPTY" | "ANY" | Mixed | children]
	child-chars: charset "?*+"
	children: [[choice | seq] opt child-chars]
	cp: [[Name | choice | seq] opt child-chars]
	choice: [#"(" opt S cp some [opt S #"|" opt S cp] opt S #")"]
	seq: [#"(" opt S cp some [opt S #"," opt S cp] opt S #")"]
	Mixed: [
		#"(" opt S "#PCDATA" any [opt S #"|" opt S Name] opt space ")*"
	|	#"(" opt S "#PCDATA" opt S #")"
	]

	; -- Attributes
	AttlistDecl: ["<!ATTLIST" S Name any AttDef opt S #">"]
	AttDef: [S Name S AttType S DefaultDecl]
	AttType: [StringType | TokenizedType | EnumeratedType]
	StringType: "CDATA"
	TokenizedType: ["IDREF" | "ID" | "IDREFS" | "ENTITY" | "ENTITIES" | "NMTOKENS" | "NMTOKEN"] ; NOTE: sorted differently than in spec to actually work

	EnumeratedType: [NotationType | Enumeration]
	NotationType: ["NOTATION" S #"(" opt S Name any [opt S #"|" opt S] opt S #")"]
	Enumeration: [#"(" opt S Nmtoken any [opt S #"|" opt S Nmtoken] opt S #")"]
	DefaultDecl: ["#REQUIRED" | "#IMPLIED" | opt ["#FIXED" S] AttValue]

	; -- Conditional Sections
	conditionalSect: [includeSect | ignoreSect]
	includeSect: ["<![" opt S "INCLUDE" opt S #"[" extSubsetDecl "]]>"]
	ignoreSect: ["<![" opt S "IGNOREE" opt S #"[" any ignoreSectContents "]]>"]
	ignoreSectContents: [Ignore any ["<![" ignoreSectContents "]]>" Ignore]]
	Ignore: [any [not ["<![" | "]]>"] Char]]

	; -- Physical Structures

	number: charset "0123456789"
	hexnum: union number charset "abcdefABCDEF"
	CharRef: [ "&#" some number #";" | "&#x" some hexnum #";"]
	Reference: [EntityRef | CharRef]
	EntityRef: [#"&" Name #";"]
	PERreference: [#"%" Name #";"]

	; -- Entity Declaration

	EntityDecl: [GEDecl | PEDecl]
	GEDecl: ["<!ENTITY" S Name S EntityDef opt S #">"]
	PEDecl: ["<!ENTITY" S #"%" S Name S PEDef opt S #">"]
	EntityDef: [EntityValue | ExternalID opt NDataDecl]
	PEDef: [EntityValue | ExternalID]
	ExternalID: ["SYSTEM" S SystemLiteral | "PUBLIC" S PubidLiteral S SystemLiteral]
	NDataDecl: [S "NDATA" S Name]
	TextDecl: ["<?xml" opt VersionInfo EncodingDecl opt S "?>"]
	extParsedEnt: [opt TextDecl not any Char content RestrictedChar any Char]
	EncodingDecl: [S "encoding" Eq [dq EncName dq | sq EncName sq]]
	enc-chars: union alphanum charset "._"
	EncName: [letters any [letters | #"-"]]
	
	; -- Notation Declarations
	NotationDecl: ["<!NOTATION" S Name S [ExternalID | PublicID] opt S #">"]
	PublicID: ["PUBLIC" S PubidLiteral]
]
