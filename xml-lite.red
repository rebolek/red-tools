Red []

; TODO: conversion of map keys to word! if possible

;rl: read-thru http://red-lang.org

; for content see page/html/body/20

test: {<!--this is sparta, err comment--><a href="blabla"><b>bleble</b></a>}
xx: {^/<head>^/<link type='text/css' rel='stylesheet' href='https://www.blogger.com/static/v1/widgets/2258130529-css_bundle_v2.css' />^/<meta content='width=1100' name='viewport'/>^/</head>^/}
xy: {
<!DOCTYPE html>
<html class='v2' dir='ltr' xmlns='http://www.w3.org/1999/xhtml' xmlns:b='http://www.google.com/2005/gml/b' xmlns:data='http://www.google.com/2005/gml/data' xmlns:expr='http://www.google.com/2005/gml/expr'>
<head>
<link type='text/css' rel='stylesheet' href='https://www.blogger.com/static/v1/widgets/2258130529-css_bundle_v2.css' />
<meta content='width=1100' name='viewport'/>
<meta content='text/html; charset=UTF-8' http-equiv='Content-Type'/>
<meta content='blogger' name='generator'/>
</head>
</html>
}

xz: {
<link type='text/css' rel='stylesheet' href='https://www.blogger.com/static/v1/widgets/2258130529-css_bundle_v2.css' />
<meta content='width=1100' name='viewport'/>
<meta content='text/html; charset=UTF-8' http-equiv='Content-Type'/>
<meta content='blogger' name='generator'/>
}

google: https://www.google.cz/search?q=bullerbyne
malf-scr: {<script>x=x+1;x<5</script>} ; google uses this...

; TODO: move tests to separate file

tests: [
	;
	; FORMAT: source result
	;
	; comments
	{<!-- a comment -->} []
	{<!-- a comment --> <!-- another comment -->} []
	;
	; single tags
	{<img/>} [img #()]
	{<img src="http://www.image.com/image.jpg"/>} [img none #("src" "http://www.image.com/image.jpg")]
	{<img src="http://www.image.com/image.jpg" />} [img none #("src" "http://www.image.com/image.jpg")]
	{<img src="http://www.image.com/image.jpg"/><img src="http://www.image.com/image.jpg"/>} [img none #("src" "http://www.image.com/image.jpg") img none #("src" "http://www.image.com/image.jpg")]
	{<img src="http://www.image.com/image.jpg"/> <img src="http://www.image.com/image.jpg"/>} [img none #("src" "http://www.image.com/image.jpg") img none #("src" "http://www.image.com/image.jpg")]
	{<!-- a comment --><img src="http://www.image.com/image.jpg"/><!-- a comment -->} [img none #("src" "http://www.image.com/image.jpg")]
]

run-tests: function [
	tests
] [
	output: clear {}
	index: 1
	foreach [test result] tests [
		repend output either equal? xml-lite/decode test result [
			["Test #" index " passed." newline]
		] [
			["Test #" index " failed." newline]
		]
		index: index + 1
	]
	copy output
]

debug: func [value] [if debug? print value]

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
		copy name= some tag-name
		ws atts ws
		#">" ws
		push-atts
		(append stack name=)
		keep (to word! name=)
		[if (reverse?) keep pop-atts | none]
	]
	close-tag: [
		ws "</"
		(name=: take/last stack)
		name=
		#">" ws
		[if (not reverse?) pop-atts | none]
	]
	close-char: #"/"
	action: none
	single-tag: [
		(close-char: #"/")
		ws #"<" opt [#"!" (close-char: "")]
		copy name= [
			single-tags (close-char: "")
		|	some tag-name
		]
	;	(print "==single:" mold name=)
		ws atts ws
		close-char #">" ws
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
	|	string (debug ["strn" copy/part s e])
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

show-h: does [
	page: xml-lite/decode read http://www.red-lang.org
	headings: select-by-class page "post-title"
	foreach [t c a] headings [print c/a/2]
]
