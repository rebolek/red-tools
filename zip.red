Red[
	Title: "ZIP packer and unpacker"
	Author: "Boleslav Březovský"
	
]

context [
; -- support functions ------------------------------------------------------------

to-ilong: func [
"Converts an integer to a little-endian long"
	value [integer!] "Value to convert"
][
	reverse to binary! value
]

to-ishort: func [
	"Converts an integer to a little-endian short"
	value [integer!] "Value to convert"
][
	reverse skip to binary! value 2
]

load-ishort: func [
	"Converts little-endian short to integer"
	value [binary!] "Value to convert"
][
	to integer! reverse value
]

load-number: func [data][to integer! reverse data]

to-msdos-date: func [
	"Converts to a msdos date"
	value [date!] "Value to convert"
][
	to-ishort 512 * (max 0 value/year - 1980) or (value/month * 32) or value/day
]

to-msdos-time: func [
	"Converts to a msdos time."
	value [time!] "Value to convert"
][
	to-ishort (value/hour * 2048) or (value/minute * 32) or (to integer! value/second / 2)
]

load-msdos-time: func [
	"Converts from a msdos time"
	value [binary!] "Value to convert"
][
	value: load-ishort value
	to time! reduce [
		63488 and value / 2048
		2016 and value / 32
		31 and value * 2
	]
]

load-msdos-date: func [
	"Converts from a msdos date"
	value [binary!] "Value to convert"
][
	value: load-ishort value
	to date! reduce [
		65024 and value / 512 + 1980
		480 and value / 32
		31 and value
	]
]

global-signature: #{504B0102}
local-signature: #{504B0304}
central-signature: #{504B0506}

; -- internal functions -----------------------------------------------------------

gp-bitflag: func [][
	; bit 0 - encryption
	; bit 1&2 - method: normal, maximum, fast, super fast
	; bit 3 - are crc&sizes in local header?
	; bit 4 - enhanced deflating(?)
	; bit 5 - compressed pached data
	; bit 6 - strong encryption
	; bit 7-11 - unused
	; bit 12 - 15 - reserved

	flag: make bitset! 16
	to binary! flag
]

make-entry: func [
	"Make Zip archive entry"
	filename [file!]
	/local local-header global-header data crc
		orig-size comp-size name-size filedate
][
	data:	read/binary filename
	crc:	to-ilong checksum data 'crc32
	orig-size:	to-ilong length? data
	data:	compress/deflate data
	comp-size:	to-ilong length? data
	name-size:	to-ishort length? filename
	filedate:	query filename

	; -- make header
	local-header: rejoin [
		local-signature
		#{0000}		; version needed to extract
		gp-bitflag	; bitflag
		#{0800}		; compression method - DEFLATE
		to-msdos-time filedate/time
		to-msdos-date filedate/date
		crc
		comp-size
		orig-size
		name-size
		#{0000}		; extra field length
		filename
		#{}			; no extra field
	]
	append local-header data
	global-header: rejoin [
    	global-signature
		#{0000}		; source version
		#{0000}		; version needed to extract
		gp-bitflag	; bitflag
		#{0800}		; compression method - DEFLATE
		to-msdos-time filedate/time
		to-msdos-date filedate/date
		crc
		comp-size
		orig-size
		name-size
		#{0000}		; extra field length
		#{0000}		; file comment length
		#{0000}		; disk number start
		#{0000}		; internal attributes
		#{00000000}	; external attributes
		#{00000000}	; header offset
		filename
		#{}			; extrafield
		#{}			; comment
	]
	reduce [local-header global-header]
]

; -- in-Red functions -------------------------------------------------------------

set 'make-zip func [
	"Make ZIP archive from file or block of files. Returns binary!"
	files [block! file!] "File(s) to archive"
	/local length archive central-directory arc-size entry
][
	files: append clear [] files
	length: to-ishort length? files
	archive: copy #{}
	central-directory: copy #{}
	arc-size: 0
	while [not tail? files][
		entry: make-entry first files
		; write file offset in archive
		change skip entry/2 42 to-ilong arc-size
		; directory entry
		append central-directory entry/2
		; compressed file + header
		append archive entry/1
		arc-size: arc-size + length? entry/1
		files: next files
	]
	rejoin [
		archive
		central-directory
		central-signature
		#{0000}				; disk number
		#{0000}				; disk central directory
		length				; entries
		length				; entries disk
		to-ilong length? central-directory
		to-ilong arc-size
		#{0000}				; comment length
		#{}					; comment
	]
]

set 'load-zip func [
	"Extract ZIP archive to block of Red values"
	data	[binary!] "ZIP archive data"
	/meta	"Include metadata also"
	/local files metadata start mark time date comp
		comp-size orig-size name-size extra-size comment-size
		offset filename extrafield comment

][
	files: copy #()
	metadata: copy #()
	parse data [
		start:
		some [to local-signature]
		to global-signature
		some [
			global-signature
			4 skip	; versions
			2 skip	; flags
			copy method 2 skip
			(
				method: select [0 store 8 deflate] load-ishort method
				; TODO: add error handling for unsupported methods
			)
			copy time 2 skip
			copy date 2 skip
			4 skip	; crc
			copy comp-size 4 skip (comp-size: load-number comp-size)
			copy orig-size 4 skip (orig-size: load-number orig-size)
			copy name-size 2 skip (name-size: load-number name-size)
			copy extra-size 2 skip (extra-size: load-number extra-size)
			copy comment-size 2 skip (comment-size: load-number comment-size)
			8 skip	; various attributes
			copy offset 4 skip (offset: load-number offset)
			copy filename name-size skip (filename: to file! filename)
			copy extrafield extra-size skip
			copy comment comment-size skip
			mark:
			(start: skip head start offset)
			:start
			local-signature
			22 skip ; mandatory fields
			copy name-size 2 skip (name-size: load-number name-size)
			copy extra-size 2 skip (extra-size: load-number extra-size)
			name-size skip
			extra-size skip
			copy comp comp-size skip
			(
			;	print [filename method offset comp-size]
				files/:filename: switch method [
					store	[comp]
					deflate	[decompress/deflate comp orig-size]
				]
				date: load-msdos-date date
				date/time: load-msdos-time time
				metadata/:filename: context compose [
					date: (date)
				]
			)
			:mark
		]
	]
	either meta [reduce [files metadata]][files]
]

; -- file functions ---------------------------------------------------------------

set 'zip func [
	"Save ZIP archive created from given files or paths"
	where [file!]	"Where to save"
	files [file!]	"File(s) and/or path(s) to archive"
][
]

set 'unzip func [
	"Extract files from ZIP archive"
	value [file!]	"ZIP archive to extract"
	/local data file content
][
	data: load-zip read/binary value
	foreach [file content] data [
		either dir? file [
			make-dir/deep file
		][
			write/binary file content
		]
	]
	true
]

; -- end of context
]
