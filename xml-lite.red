Red []

debug: func [value] [if debug? [print value wait 0.1]]

debug?: no

; ============================================================================

; TODO: NAME* rules should be CHAR*

xml-lite: context [

	; === SETTINGS ===========================================================

	empty-value: none   ; used for single tags that have no content
	reverse?: no        ; normal order is [tag-name content attributes],
					    ; reversed order is [tag-name attributes content]
	align-content?: yes ; store HTML strings as one or three values:
						; string or [NONE string NONE]  
						; this required for traversing with FOREACH-NODE

	; === RULES ==============================================================

	document: [
		(clear stack)
		(clear atts-stack)
		some content
	]
	whitespace: charset " ^-^/^M"
	ws: [any whitespace]

	chars: charset [#"a" - #"z" #"A" - #"Z" #"0" - #"9"]
;	tag-name: union name charset #"!" ; TODO: support full range
	tag-name: chars
	push-atts: [(append atts-stack copy atts=)]
	pop-atts: [keep (take/last atts-stack)]

	single-tags: ["img" | "meta" | "link" | "br" | "hr" | "input"] ; TODO...
	open-tag: [
		ws #"<"
		not ahead single-tags
		(debug "--open-tag?")
		copy name= some tag-name
		(debug ["--open-tag" mold name=])
		ws atts ws
		#">"
		push-atts
		(append stack name=)
		keep (to word! name=)
		[if (reverse?) pop-atts | none]
	]
	close-tag: [
		ws "</"
		(name=: take/last stack)
		name=
		#">"
		(name=: none)
		[if (not reverse?) pop-atts | none]
	]
	close-char: #"/"
	action: none
	single-tag: [
		(close-char: #"/")
		ws #"<" opt [#"!" (close-char: "")]
		(debug "--single-tag?")
		copy name= [
			single-tags (close-char: [opt #"/"])
		|	some tag-name
		]
		(debug  ["--single-tag" mold name=])
		ws atts ws
		close-char #">"
		push-atts
		keep (to word! name=)
		[
			if (reverse?) [
				pop-atts
				keep (empty-value) ; empty content
			]
		|	if (not reverse?) [
				keep (empty-value) ; empty content
				pop-atts
			]
		]
	]
	not-att-chars: union whitespace charset [#">" #"/" #"="]
	att-name: union chars charset ":-_"
	pair-att: [
		ws not #"/"
		copy att-name= some att-name
		#"=" [
			set quot-char [#"^"" | #"'"]
			copy att-value= to quot-char skip
		|	copy att-value= to [#">" | whitespace]
		]
		ws
		(atts=/:att-name=: att-value=)
	]
	single-att: [
		ws not #"/"
		copy att-name= some att-name
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
			if (equal? name= "script") not ahead </script> skip ; accept #"<" inside <script>...</script> (Google does it)
		|	ahead #"<" break
		|	skip
		] 
		e: 
		[
			if (align-content?) [
				keep (none)
				keep (copy/part s e)
				keep (#()) ; TODO: should be user defined?
			]
		|	if (not align-content?) [keep (copy/part s e)]
		]
	]
	
	content: [
		ahead "</" break
	|	comment (debug ["cmnt" name=])
	|	some [open-tag (debug ["open" name=]) collect some content close-tag (debug ["clos" name=])]
	|	single-tag (debug ["sngl" name=])
	|	string (debug ["strn" t: copy/part s e length? t])
	]

	atts-stack: []
	stack: []
	name=: none
	atts=: #()
	att-name=:
	att-value=: none

	decode: func [
		data
	] [
		parse data [collect document]
	]
]

foreach-node: func [
	data
	code
] [
	; FN takes three parameters: [tag content attribute] (or just two? without content)
	foreach [tag content attributes] data [
		do bind code 'tag
		if block? content [
			foreach-node content code
		]
	]
]

probe-xml: func [
	data
] [
	foreach [tag content attributes] data [
		print [tag length? content length? attributes]
	]
]

select-by-tag: func [
	data
	tag
] [
	ret: copy []
	foreach-node data compose [
		if equal? tag (to lit-word! tag) [
			append ret reduce [tag content attributes]
		]
	]
	ret
]

select-by-class: func [
	data
	class
] [
	ret: copy []
	foreach-node data compose [
		if find select attributes "class" (class) [
			append ret reduce [tag content attributes]
		]
	]
	ret
]

select-by-content: func [
	data
	value
] [
	ret: copy []
	foreach-node data compose/deep [
		all [
			string? content
			find content (value)
			append ret reduce [tag content attributes]
		]
	]
	ret
]

get-text: func [
	data
] [
	ret: copy {}
	foreach-node data compose/deep [
		all [
			string? content
			append ret content
		]
	]
	ret
]

show-h: does [
	page: xml-lite/decode read http://www.red-lang.org
	headings: select-by-class page "post-title"
	foreach [t c a] headings [print c/a/2]
]

google: func [value] [
	debug "Loading page"
	page: rejoin [http://www.google.cz/search?q= replace/all value space #"+"]
	page: read/binary probe page
	write %goog.html page
	debug "Decoding page"
	page: load-non-utf page
	debug "Page read"
	page: xml-lite/decode page
	results: select-by-tag page 'h3
	result: collect [
		foreach [t c a] results [keep reduce [get-text c/a rejoin [http://www.google.com select c/3 "href"]]]
	]
	new-line/all/skip result true 2
]

get-table: func [
	"Convert <table> to block! of block!s"
	table
] [
	collect [
		foreach [t c a] table [ ; row
			row: c
			keep/only collect [
				foreach [t c a] row [
					if c [
						text: get-text c
						keep text
					]
				]
			]
		]
	]
]