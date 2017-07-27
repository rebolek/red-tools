Red[]

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