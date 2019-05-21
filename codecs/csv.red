Red [
	Title: "CSV Parser"
	Author: "Boleslav Březovský"
	Date: "21-3-2017"
	Rights:  "Copyright (C) 2017 Boleslav Březovský. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

csv: object [
	ignore-empty?: true ; If line ends with delimiter, do not add empty string
	parsed?: none		; Keep state of parse result (for debugging purposes)
	decode: function [
		data [string! file! url!] "Text CSV data to load"
		/with
			delimiter "Delimiter to use (default is comma)"
		/header	"Treat first line as header (returns map!)"
		/map	"Return map! (keys are named by letters A-Z, AA-ZZ, ...)"
	] [
		; initialization
		if header [map: true]
		unless with [delimiter: #","]
		if any [file? data url? data] [data: read data]
		output: make block! (length? data) / 80
		out-map: make map! []
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
				some [
					[
						set char quotchars
					|	quot quot (char: #"^"")
					]
					(append value char)
				]
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
		parsed?: parse data [
			opt [
				if (header) 
				values single-value add-value newline
				(header: copy line)
				(clear line)
			]
			any line-rule
			(clear line)
			values single-value add-line
			opt newline
		]
		; adjust output when needed
		if map [
			; TODO: do not use first, but longest line
			header: any [header make-header length? first output]
			key-index: 0
			foreach key header [
				key-index: key-index + 1
				out-map/:key: make block! length? output
				foreach line output [append out-map/:key line/:key-index]
			]
			output: out-map
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

	make-header: function [
		"Return default header (A-Z, AA-ZZ, ...)"
		length
	][
		key: copy "A"
		collect [
			loop length [
				key-length: length? key
				keep copy key
				key/:key-length: key/:key-length + 1
				repeat i key-length [
					position: key-length - i + 1
					; last char reached?
					if equal? #"[" key/:position [
						either key/1 > #"Y" [
							key/:position: #"A"
							key/1: #"A"
							insert head key #"A"
						][
							key/:position: #"A"
							key/(position - 1): key/(position - 1) + 1
							i: i + 1
						]
					]
				]
			]
		]
	]


; TODO
	encode-map: func [
		"Make CSV data from map! of columns"
		data
	][
		data
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
		unless block? first data [data: reduce [data]] ; Only one line
		; check if it's block of maps/objects
		types: unique collect [foreach value data [keep type? value]]
		either all [
			1 = length? types
			any [equal? map! types/1 equal? object! types/1]
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
