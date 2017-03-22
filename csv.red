Red [
	Title: "CSV Parser"
	Author: "Boleslav Březovský"
	Date: "21-3-2017"
	Rights:  "Copyright (C) 2017 Boleslav Březovský. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

load-csv: function [
	data [string! file! url!] "Text CSV data to load"
	/with
		delimiter "Delimiter to use (default is comma)"
] [
	; initialization
	unless with [delimiter: #","]
	if any [file? data url? data] [data: read data]
	output: make block! (length? data) / 80
	line: make block! 20
	value: make string! 200
	quot: #"^""
	stop: charset [#"^/" #"^M" #","]
	valchars: charset [not "^/^M,"]
	quotchars: charset reduce ['not quot]
	; parse rules
	quoted-value: [
		quot (clear value)
		some [set char [{""} | quotchars] (append value char)]
		quot
	]
	normal-value: [s: any valchars e: (value: copy/part s e)]
	single-value: [quoted-value | normal-value]
	values: [some [single-value comma add-value]]
	add-value: [(append line copy value)]
	add-line: [
		add-value ; add last value on line
		(
			append/only output copy line
			clear line
		)
	]
	line-rule: [values single-value newline add-line]
	; main code
	parse data [
		some line-rule
		values single-value add-line
	]
	output
]