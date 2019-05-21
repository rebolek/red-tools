Red [
	Title: "CSV Parser"
	Author: "Boleslav Březovský"
	Date: "21-3-2017"
	Rights:  "Copyright (C) 2017 Boleslav Březovský. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

csv: object [
	ignore-empty?: true ; If line ends with delimiter, do not add empty string
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
			(clear value) [
				quot quot
			|	quot
				some [set char quotchars (append value char)]
				quot
			]
		]
		normal-value: [s: any valchars e: (value: copy/part s e)]
		single-value: [quoted-value | normal-value]
		values: [some [single-value delimiter add-value]]
		add-value: [(append line copy value)]
		add-line: [
			add-value ; add last value on line
			(
				all [
					ignore-empty?
					empty? last line
					take/last line
				]
				append/only output copy line
				clear line
			)
		]
		line-rule: [values single-value newline add-line]
		; main code
		parse data [
			any line-rule
			(clear line)
			values single-value add-line
		]
		output
	]

	to-csv-line: function [
		data
		/with
			delimiter
		/only "Do not add newline"
	] [
		unless with [delimiter: comma]
		collect/into [
			foreach value data [
				keep rejoin [escape-value/with value delimiter delimiter]
			]
		] output: make string! 1000
		head remove back tail output ; TODO: expects delimiter to be of size 1
		unless only [append output newline]
		output
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

	encode: func [
		"Make CSV data from input value"
		data
		/with
			delimiter
		/local
			types value line columns
	] [
		unless with [delimiter: comma]
		unless block? data [data: reduce [data]] ; Only one line
		; check if it's block of maps/objects
		types: unique collect [foreach value data [keep type? value]]
		either all [
			1 = length? types any [equal? map! types/1 equal? object! types/1]
		][
			; this is block of maps/objects
			columns: get-columns data
			output: to-csv-line/with columns delimiter
			append output collect/into [
				foreach value data [
					; construct block
					line: collect [
						foreach column columns [
							keep value/:column ; FIXME: this can be problematic when key isn't in object
						]
					]
					keep to-csv-line/with line delimiter
				]		
			] make string! 1000		
		][
			; this is block of blocks	
			collect/into [
				foreach line data [
					keep to-csv-line/with line delimiter
				]
			] make string! 1000
		]
	]
	get-columns: func [
		"Return all keywords from maps or objects"
		data "Data must block of maps or objects"
		/local columns
	][
		columns: words-of data/1
		foreach value data [
			append columns difference columns words-of value 
		]
		columns
	]
]
