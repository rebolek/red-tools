Red [
	Title: "CSV codec"
	Author: "Boleslav Březovský"
	Date: "21-3-2017"
	Rights:  "Copyright © 2017-2019 Boleslav Březovský. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
	To-Do: [
		{`decode/map`: if record is longer than header, surplus fields are ignored}
		{optional error on inconsistent number of fields in record}
		{support /flat and /align together}
	]
	Documentation: {
# Introduction

CSV codec implements CSV/DSV parser and emmiter for Red language. It implements
RFC 4180 support with extension to support non-standard data.

## DECODE

Decode converts `string!` of CSV data to Red `block!` or `map!`, depending on
the mode. Usage is simple:

	csv/decode csv-data

There are some refinements to modify function behaviour:

* /with delimiter - Use different delimiter. Comma is default.

* /header - Treat first line as header. Will return `map!` with columns as keys.

* /map - Return `map!` of columns. If `/header` is not used, columns are named
automatically from A to Z, then from AA to ZZ etc. `/map/header` is same as
`/header`.

* /block - Return `block!` of `map!`s. Keys are named by columns using same
rules as with `/map` refinement.

NOTE: `/block` and `map` cannot be used together.

* /align - if records have different length, align shorted records with `none`.

There is also `ignore-empty?` value in `CSV` object that switches automatical
removal of last field, when it's empty (some software adds comma to end of
record).

## ENCODE

Encode takes `block!`, `map!` or `object!` and returns `string!` of CSV data.

There are some refinements to modify function behaviour:

* /with delimiter - Use different delimiter. Comma is default.

* /skip size - Treat `block!` as table of records with `size` fields.
}
]

csv: object [
	; -- state variables
	ignore-empty?: true ; If line ends with delimiter, do not add empty string
	quot: #"^""

	; -- internal values
	parsed?: none		; Keep state of parse result (for debugging purposes)

	; -- support functions
	to-csv-line: function [
		data
		delimiter
		/only "Do not add newline"
	] [
		collect/into [
			foreach value data [
				keep rejoin [escape-value/with value delimiter delimiter]
			]
		] output: make string! 1000
		take/part/last output length? form delimiter
		unless only [append output newline]
		output
	]

	_escape-value: function [
		value
		/with
			delimiter
	] [
		unless with [delimiter: comma]
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

	escape-value: function [
		value
		delimiter
	][
	; TODO: this replaces " with "", but what if we choose different char
	;		as string delimiter, like ' ?
		value: form value
		parse value [
			some [
				change #"^"" {""} (quot?: true)
			|	[space | quot | delimiter](quot?: true)
			|	skip
			]
		]
		if quot? [
			insert value quot
			append value quot
		]
		value
	]

	next-column-name: function [
		"Return name of next column (A->B, Z->AA, ...)"
		name
	][
		length: length? form name
		repeat index length [
			position: length - index + 1
			previous: position - 1
			either equal? #"Z" name/:position [
				name/:position: #"A"
				if position = 1 [
					insert name #"A"
				]
			][
				name/:position: name/:position + 1
				break
			]
		]
		name
	]

	make-header: function [
		"Return default header (A-Z, AA-ZZ, ...)"
		length
	][
		key: copy "A"
		collect [
			keep copy key
			loop length - 1 [
				keep copy key: next-column-name key
			]
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

	encode-map: function [
		"Make CSV data from map! of columns"
		data
		delimiter
	][
		output: make string! 1000
		keys: keys-of data
		append output to-csv-line keys delimiter
		repeat index length? select data first keys [
			line: make string! 100
			append output to-csv-line collect [
				foreach key keys [keep data/:key/:index]
			] delimiter
		]
		output
	]

	encode-flat: function [
		data
		delimiter
		size
	][
		unless zero? (length? data) // size [
			return make error! "Block is not properly aligned"
		]
		collect/into [
			until [
				keep to-csv-line copy/part data size delimiter
				tail? data: skip data size
			]
		] make string! 1000
	]

	; -- main functions
	decode: function [
		data [string! file! url!] "Text CSV data to load"
		/with
			delimiter [char! string!] "Delimiter to use (default is comma)"
		/header	"Treat first line as header (returns map! when not used with /block)"
		/map	"Return map! (keys are named by letters A-Z, AA-ZZ, ...)"
		/block	"Return block of maps"
		/flat	"Return flat block instead of block of blocks"
		/align	"Align all records to have same length as longest record"
	] [
		; -- init local values
		delimiter: any [delimiter comma]
		output: make block! (length? data) / 80
		out-map: make map! []
		longest: 0
		line: make block! 20
		value: make string! 200

		; -- parse rules
		quotchars: charset reduce ['not quot]
		valchars: charset reduce ['not append copy "^/^M" delimiter]
		quoted-value: [
			(clear value) [
				quot
				any [
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
				; remove last empty element, when required
				all [
					ignore-empty?
					empty? last line
					take/last line
				]
				; append line to output
				either block [
					length: length? header
					; extend header when needed
					if longest > length [
						loop longest - length [
							append header next-column-name last header
						]
						length: longest
					]
					; append line to output
					value: make map! length
					repeat index length [
						value/(header/:index): line/:index
					]
					append output copy value
				][
					if longest < length? line [longest: length? line]
					either flat [
						append output copy line
					][
						append/only output copy line
					]
				]
				clear line
			)
		]
		line-rule: [values single-value newline add-line]

		; -- initialization
		if all [map block][
			return make error! "Cannot use /map and /block refinements together"
		]
		if all [flat align][
			return make error! "Cannot use /flat and /align refinements together"
		]
		if all [header not block][map: true]
		unless with [delimiter: #","]
		if any [file? data url? data] [data: read data]

		; -- main code
		parsed?: parse data [
			opt [
				if (header) 
				values single-value add-value newline
				(header: copy line)
				(clear line)
			]
			(
				if all [block not header][
					header: make-header 30 ; Will be expanded when necessary
				]
			)
			any line-rule
			(clear line)
			values single-value add-line
			opt newline
		]

		; -- adjust output when needed
		if align [
			foreach line output [
				if longest > length? line [
					append/dup line none longest - length? line
				]
			]
		]
		if map [
			; TODO: do not use first, but longest line
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

	encode: function [
		"Make CSV data from input value"
		data [block! map! object!]
		/with
			delimiter [char! string!]
		/skip	"Treat block as table of records with fixed length"
			size [integer!]
	][
		unless with [delimiter: comma]
		if any [map? data object? data][return encode-map data delimiter]
		if skip [return encode-flat data delimiter size]
		keyval?: any [map? first data object? first data]
		unless any [
			block? first data
			keyval?
		][data: reduce [data]] ; Only one line
		; check if it's block of maps/objects
		types: unique collect [foreach value data [keep type? value]]
		either all [
			1 = length? types
			keyval?
		][
			; this is block of maps/objects
			columns: get-columns data
			output: to-csv-line columns delimiter
			append output collect/into [
				foreach value data [
					; construct block
					line: collect [
						foreach column columns [
							keep value/:column ; FIXME: this can be problematic when key isn't in object
						]
					]
					keep to-csv-line line delimiter
				]		
			] make string! 1000
		][
			; this is block of blocks
			collect/into [
				foreach line data [
					keep to-csv-line line delimiter
				]
			] make string! 1000
		]
	]
]
