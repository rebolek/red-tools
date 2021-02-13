Red [
	Title:          "XML"
	Description:    "Encoder and decoder for XML and HTML format"
	Author:         "Boleslav Březovský"
	Notes: [
{
== UNCLOSED <P> TAG ==

A p element’s end tag may be omitted if the p element is immediately followed
by an address, article, aside, blockquote, dir, div, dl, fieldset, footer,
form, h1, h2, h3, h4, h5, h6, header, hr, menu, nav, ol, p, pre, section,
table, or ul element, or if there is no more content in the parent element
and the parent element is not an a element.
}
	]
]

debug: func [
	value
	/init
] [
	if all [debug? init] [write value "" exit]
	if debug? [
		write/append %debug value
		print value
		print [
			"stack:" length? xml/stack
			"atts-stack:" length? xml/atts-stack
			rejoin [index? xml/pos "/" length? xml/doc]
		]
		if (length? xml/stack) <> (length? xml/atts-stack) [
			print "stacks differ"
			halt
		]
;		wait 0.02
;		if "q" = ask "Q to quit:" [halt]
	]
]
debug?: yes
debug/init %debug

; ============================================================================

; TODO: NAME* rules should be CHAR*

xml: context [

	; === SETTINGS ===========================================================

	empty-value: none   ; used for single tags that have no content
	align-content?: yes ; store `HTML` strings as one or three values:
						; `string` or  `[NONE string NONE]`  
						; this required for traversing with `foreach-node`
	key-type: string!	; `string!` or `word!` for conversion where possible 

	; === RULES ==============================================================

	s: e: t: none

	push-atts: [(append atts-stack copy atts=)]
	pop-atts: [keep (take/last atts-stack)]

	document: [
		(clear stack)
		(clear atts-stack)
		some content
	]
	whitespace: charset " ^-^/^M"
	ws: [any whitespace]
	name-start-char: charset [
		":_" #"a" - #"z" #"A" - #"Z" #"0" #"^(C0)" - #"^(D6)" #"^(D8)" - #"^(F6)" 
		#"^(F8)" - #"^(02FF)" #"^(0370)" - #"^(037D)" #"^(037F)" - #"^(1FFF)"
		#"^(200C)" - #"^(200D)" #"^(2070)" - #"^(218F)" #"^(2C00)" - #"^(2FEF)"
		#"^(3001)" - #"^(D7FF)" #"^(F900)" - #"^(FDCF)" #"^(FDF0)" - #"^(FFFD)"
		#"^(010000)" - #"^(0EFFFF)"
	]
	name-char: union name-start-char charset [
		"-." #"0" - #"9" #"^(B7)" #"^(0300)" - #"^(036F)" #"^(203F)" - #"^(2040)"
	]
	name: [name-start-char any name-char]
	single-tags: [
		"area" | "base" | "br" | "col" | "command" | "embed" | "hr" | "img"
	|	"input" | "keygen" | "link" | "meta" | "param" | "source" | "track"
	|	"wbr"
	]
	open-tag: [
		ws #"<"
		not ahead single-tags
		(debug "--open-tag?")
		copy name= some name
		(debug ["--open-tag" mold name=])
		ws atts ws
		#">"
		push-atts
		(append stack name=)
		keep (to word! name=)
	]
	close-tag: [
		(debug "--close-tag?")
		close-p-tag
	|	ws "</"
		(name=: last stack)	; first we test the name
		name=				; and if it matches, we can remove it
		(take/last stack)	; this prevents stack corruption
		#">"				; in case of badly writen HTML (wild close tag)
		(close=: name=) ; for debug purpose only
		(name=: none)
		pop-atts
	]
	wild-close-tag: [
		ws "</" 
		(name=: last stack)
		if (not equal? "p" name=)	; <p> can be unlcosed so it's not error
		not name=
		copy name= some name #">"
	]
	close-p-tag: [
; there are three ways to close <p> tag:
		if ("p" = last stack)
		(para?: false)
		pos:
		(debug ["|para|" mold stack mold pos])
		ws "</" [
	; 1. </p>
			(name=: last stack)
			name=
			(take/last stack)
			#">"
	; 2. close parent tag
		|	(name=: first back back stack)
			name=
			(take/last stack)
			(para?: true)
			:pos
		]
		(close=: name=) ; for debug purpose only
		(name=: none)
		pop-atts
		(debug "closed para")
; 3. open tag from list below
		; TODO
	]
	end-p-tag: [
		"address" | "article" | "aside" | "blockquote" | "dir" | "div" | "dl"
	|	"fieldset" | "footer" | "form" | "h1" | "h2" | "h3" | "h4" | "h5"
	|	"h6" | "header" | "hr" | "menu" | "nav" | "ol" | "p" | "pre"
	|	"section" | "table" | "ul"
	]
	close-char: #"/"
	action: none
	single-tag: [
		(close-char: #"/")
		ws #"<" opt [#"!" (close-char: "")]
		(debug "--single-tag?")
		copy name= [
			single-tags (close-char: [opt #"/"])
		|	some name
		]
		(debug ["--single-tag" mold name=])
		ws atts ws
		close-char #">"
		opt ["</" name= #">"]
		push-atts
		keep (to word! name=)
		keep (empty-value) ; empty content
		pop-atts
	]
	;TODO: for HTML attribute names, #":" should be excluded
	pair-att: [
		ws not #"/"
		copy att-name= some name
		#"=" [
			set quot-char [#"^"" | #"'"]
			copy att-value= to quot-char skip
		|	copy att-value= to [#">" | whitespace]
		]
		ws (
			all [
				equal? word! key-type
				try [t: to set-word! att-name=]
				att-name=: t
			]
			atts=/:att-name=: att-value=
		)
	]
	single-att: [
		ws not #"/"
		copy att-name= some name
		ws
		(atts=/:att-name=: true)
	]
	atts: [
		(atts=: copy #()) ; FIXME: IMO `clear` should be enough here, but it is not
		ws any [pair-att | single-att]
	]
	comment: [ws "<!--" thru "-->" ws]
	string: [
		s: any [
			if (find ["script" "pre"] name=) not ahead ["</" name= #">"] skip 
			; accept #"<" inside <script> and <pre>
		|	ahead ["</" | "<" name] break
		|	skip
		] 
		e: [
			if (align-content?) [
				; FIXME: three `keep`s are here because `keep` works as `keep/only`
				keep (none)
				keep (copy/part s e)
				keep (#()) ; TODO: should be user defined?
			]
		|	if (not align-content?) [keep (copy/part s e)]
		]
	]
	doctype: [
		; TODO: Add some output and better handling
		"<!DOCTYPE" thru #">"
	]
	errors: [
		wild-close-tag (debug ["|wild|" name=])
	]

	content: [
		pos:
		errors (debug ["|errr|" name=]) 	; error has higher priority
	|	ahead "</" break					; than close tag
	|	comment (debug ["|cmnt|" name=])
	|	doctype (debug ["|dctp|"])
	|	some [
			open-tag
			(debug rejoin ["|open| <" name= ">"])
			collect some content
			close-tag
			(debug rejoin ["|clse| <" close= "> stack:" mold stack])
		]
	|	single-tag (debug ["|sngl|" name=])
	|	string (debug ["|strn|" mold t: copy/part s e length? t])
	]

	atts-stack: []
	stack: []
	name=: none
	atts=: #()
	att-name=:
	att-value=: none
	doc: none
	pos: []
	para?: false	;	is the tag <p> ? - changes behavior of pop-atts
					;	must pop two attrs

	decode: func [
		data
	] [
		doc: data
		parse data [collect document]
	]

; === encoder part

	dbl-quot: #"^""
	output: make string! 10000

	enquote: function [value] [rejoin [dbl-quot value dbl-quot]]

	make-atts: function [
		data
	] [
		data: collect/into [
			foreach key keys-of data [
				keep rejoin [key #"=" enquote data/:key space]
			]
		] clear ""
		unless empty? data [insert data space]
		data
	]

	make-tag: function [
		name
		/with
			atts
		/close
		/empty
	] [
		atts: either with [rejoin [space make-atts atts]] [""]
		rejoin trim reduce [#"<" if close [#"/"] form name atts if empty [" /"] #">"] 
	]

	process-tag: function [
		data
	] [
		output: make string! 1000
		either data/1 [
			; tag
			either empty? data/2 [
				; empty tag
				debug ["single tag" mold data]
				repend output [#"<" form data/1 make-atts data/3 "/>"] 
			] [
				; tag pair
				debug ["tag pair" mold data]
				repend output [#"<" form data/1 make-atts data/3 ">"] 
				until [
					repend output process-tag take/part data/2 3
					empty? data/2
				]
				repend output ["</" form data/1 ">"]
			]
		] [
			; content
			repend output data/2
		]
		output
	]

	encode: function [
		data
	] [
		data: copy data
		clear output
		; TODO add proper header: xml/doctype
		until [
			repend output process-tag take/part data 3
			empty? data
		]
		output
	]
]
