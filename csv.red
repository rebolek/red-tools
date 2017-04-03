Red [
	Title: "CSV Parser"
	Author: "Boleslav Březovský"
	Date: "21-3-2017"
	Rights:  "Copyright (C) 2017 Boleslav Březovský. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

csv: object [
	decode: function [
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
		valchars: charset reduce ['not append copy "^/^M" delimiter]
		quotchars: charset reduce ['not quot]
		; parse rules
		quoted-value: [
			quot (clear value)
			some [set char [{""} | quotchars] (append value char)]
			quot
		]
		normal-value: [s: any valchars e: (value: copy/part s e)]
		single-value: [quoted-value | normal-value]
		values: [some [single-value delimiter add-value]]
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

	to-csv-line: function [
		data
		/with
			delimiter
	] [
		unless with [delimiter: comma]
		collect/into [
			foreach value data [
				keep rejoin [escape-value/with value delimiter delimiter]
			]
		] output: make string! 1000
		head remove back tail output ; TODO: expects delimiter to be of size 1
	]
	escape-value: function [
		value
		/with
			delimiter
	] [
		unless with [delimiter: comma]
		quot: #"^""
		value: form value
		replace/all value form quot {""} ; escape quotes
		if any [
			; TODO: rewrite using PARSE to make it faster
			find value space 
			find value quot 
			find value delimiter
		] [
			insert value quot
			append value quot
		]
		value
	]

	encode: function [
		"Make CSV data from input value"
		data
		/with
			delimiter
	] [
		unless with [delimiter: comma]
		unless block? data [data: reduce [data]] ; Only one line
		collect/into [
			foreach line data [
				keep to-csv-line/with line delimiter
				keep newline
			]
		] make string! 1000
	]
]