Red[]

context [
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
		#{504B0304}	; signature
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
    	#{504B0102}	; signature
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

	'make-zip func [
		files [block! file!]
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
			#{504B0506}			; signature
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
; -- end of context
]
