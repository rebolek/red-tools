Red []

rl: read http://red-lang.org
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

; ============================================================================

; TODO: NAME* rules should be CHAR*

xml-lite: context [

	empty-value: none ; used for single tags that have no content
	reverse?: no      ; normal order is [tag-name content attributes],
					  ; reversed order is [tag-name attributes content]

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

	open-tag: [
		ws
		#"<"
		copy name= some tag-name
		ws
		atts
		ws
		#">"
		(append atts-stack copy atts=)
		(append stack name=)
		keep (to word! name=)
		[if (reverse?) keep (take/last atts-stack) | none]
		ws
	]
	close-tag: [
		ws
		#"<"
		#"/"
		(name=: take/last stack)
		name=
		#">"
		[if (not reverse?) keep (take/last atts-stack) | none]
		ws
	]
	single-tag: [
		ws
		#"<" copy name= some tag-name
		ws
		atts
		ws
		"/>"
		(append atts-stack copy atts=)
		keep (to word! name=)
		[
			if (reverse?) [
				keep (take/last atts-stack)
				keep (empty-value) ; empty content
			]
		|	if (not reverse?) [
				keep (empty-value) ; empty content
				keep (take/last atts-stack)
			]
		]
		ws
	]
	; TODO: fix the name
	doctype-tag: [
		ws
		"<!" copy name= some tag-name
		ws
		atts
		ws
		">"
		(append atts-stack copy atts=)
		keep (to word! name=)
		[
			if (reverse?) [
				keep (take/last atts-stack)
				keep (empty-value) ; empty content
			]
		|	if (not reverse?) [
				keep (empty-value) ; empty content
				keep (take/last atts-stack)
			]
		]
		ws
	]
	not-att-chars: union whitespace charset [#">" #"/" #"="]
	att-name: union chars charset ":-_"
	pair-att: [
		ws
		not #"/"
		copy att-name= some att-name
		#"="
		set quot-char [#"^"" | #"'"]
		copy att-value= to quot-char skip
		(atts=/:att-name=: att-value=)
		ws
	]
	single-att: [
		ws
		not #"/"
		copy att-name= some att-name
		(atts=/:att-name=: true)
		ws
	]
	atts: [
		(atts=: copy #()) ; FIXME: IMO `clear` should be enough here, but it is not
		ws
		any [
			pair-att
		|	single-att
		]
	]
	comment: [ws "<!--" thru "-->" ws]
	
	content: [
		ahead "</" break
	|	comment
	|	some [open-tag collect some content close-tag]
	|	doctype-tag
	|	single-tag
	|	s: any [[ahead #"<" break] | skip] e: keep (copy/part s e)
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
