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
chip: https://en.wikipedia.org/wiki/CHIP-8

chipp: {
<!DOCTYPE html>
<html class="client-nojs" lang="en" dir="ltr">
<head>
<meta charset="UTF-8"/>
<title>CHIP-8 - Wikipedia</title>
</head>
</html>
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
]yes

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

