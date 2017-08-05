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

children?: func [
	"Return children tag names"
	data
] [
	collect [foreach [tag content attributes] data [keep tag]]
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

get-table: function [
	"Convert <table> to block! of block!s"
	table
	/trim
	/headers "First row is headers"
] [
	; TODO: support for THEAD, TBODY, TH, ...
	children: children? table
	hdrs: copy []
	if find children 'thead [
		; CHECK: Can I expect `table/thead/tr` path?
		foreach [t c a] table/thead/tr [append hdrs c/2]
	]
	if find children 'tbody [table: table/tbody]
	data: collect/into [
		foreach [t c a] table [ ; row
			row: c
			keep/only collect [
				foreach [t c a] row [
					if c [
						c: either block? c [get-text c] [c]
						if all [string? c trim] [c: system/words/trim/lines c]
						keep c
					]
				]
			]
		]
	] clear []
	if headers [
		insert/only data hdrs
	]
	new-line/all/skip data true 1
	copy data
]

; Using `get-table`:
;
; page: xml/decode read https://coinmarketcap.com/
; table: select-by page 'table 'tag
; t: get-table/trim table/table/tbody ; TODO: `get-table` should find this automatically
; probe copy/part t 5
;
; >>
; [
;     ["1" "Bitcoin" "$46,856,630,435" "$2843.13" "16,480,650 BTC" "$748,864,000" "3.85%" "" ""]
;     ["2" "Ethereum" "$18,906,132,157" "$201.78" "93,695,367 ETH" "$522,577,000" "0.44%" "" ""]
;     ["3" "Ripple" "$6,482,777,296" "$0.169117" "38,333,090,674 XRP *" "$52,118,400" "1.42%" "" ""]
;     ["4" "Litecoin" "$2,248,733,073" "$43.03" "52,255,407 LTC" "$211,233,000" "5.29%" "" ""]
;     ["5" "NEM" "$1,499,805,000" "$0.166645" "8,999,999,999 XEM *" "$2,905,890" "1.11%" "" ""]
; ]