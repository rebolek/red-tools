Red[
	Title: "HTML Tools"
	Author: "Boleslav Březovský"

]

do %xml.red

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

select-by: func [
	data
	value
	type 		; tag, class, content, attribute name
	; TODO: How to support /only ? There some binding problems
] [
	action: compose switch/default type [
		tag     [[equal? tag (to lit-word! value)]]
		class   [[find select attributes "class" (value)]]
		content [[all [string? content find content (value)]]]
	] [[equal? (value) select attributes (type)]]
	ret: copy []
	foreach-node data [
		if do action [
			append ret reduce [tag content attributes]
		]
	]
	ret
]

parent: none ; TODO: make a closure
parent?: func [
	data
	value
] [
	foreach [tag content attributes] data [
		if equal? value reduce [tag content attributes] [
			return parent
		]
		if block? content [
			parent: reduce [tag content attributes]
			if parent? content value [return parent]
		]
	]
	none
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
	data: collect/into [
		foreach [t c a] table [ ; row
			row: c
			keep/only collect [
				foreach [t c a] row [
					if c [
						keep either block? c [get-text c] [c]
					]
				]
			]
		]
	] clear []
	new-line/all/skip data true 1
	copy data
]