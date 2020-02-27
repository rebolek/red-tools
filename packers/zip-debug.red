Red[
	Title: "ZIP packer and unpacker"
	Author: "Boleslav Březovský"
	
]

.: context [

verbose?: false
info: func [value][if verbose? [print value]]

global-headers: local-headers: none

; -- support functions ------------------------------------------------------------

; FIXME: Remove once proper CLEAN-PATH is implemented in Red
strip-path: func [
	"Remove tarting %./ when present"
	value [file!]
][
	value: clean-path/only value
	if equal? %./ copy/part value 2 [
		remove/part value 2
	]
	value
]

load-dos-path: func [
	"Convert DOS style path (dir\file) to something normal"
	value [string!]
][
	to file! replace/all value #"\" #"/"
]

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

make-local-header: func [filename][
	rejoin [
		local-signature
		#{1400}		; version needed to extract (2.0 -> 20 -> #14)
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
]

make-global-header: func [filename][
	rejoin [
    	global-signature
		#{1400}		; source version (2.0 -> 20 -> #14)
		#{1400}		; version needed to extract (2.0 -> 20 -> #14)
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
]

make-entry: func [
	"Make Zip archive entry"
	filename [file!]
	/local local-header global-header data
][
	either dir? filename [
		data: #{}
		crc:
		orig-size:
		comp-size: #{00000000}
	][
		data:	read/binary filename
		crc:	to-ilong checksum data 'crc32
		orig-size:	to-ilong length? data
		data:	compress/deflate data
		comp-size:	to-ilong length? data
	]
	name-size:	to-ishort length? to binary! filename
	filedate:	query filename

	; -- make header
	local-header: make-local-header filename
	append local-header data
	global-header: make-global-header filename
	reduce [local-header global-header]
]

{
(UPath) 0x7075        Short       tag for this extra block type ("up")
TSize         Short       total data size for this block
Version       1 byte      version of this extra field, currently 1
NameCRC32     4 bytes     File Name Field CRC32 Checksum
UnicodeName   Variable    UTF-8 version of the entry File Name
}

extra-unicode-path: #{7570}

decode-extra-field: func [
	value
	/local type size version crc name
][
	if empty? value [exit]
	parse value [
		copy type extra-unicode-path [
			copy size 2 skip (size: (load-number size) - 5) ; NOTE: total size of version + crc + text
			copy version skip ; NOTE: should be 1
			copy crc 4 skip
			p: (print ["size:" size "real:" length? p])
			copy name size skip
		]
		; TODO: other types
	]
	print [
		"--- Extra ---" newline
		"Type:" type newline
		"Size:" size newline
		"Ver: " version newline
		"CRC: " crc newline
		"Name:" to string! name newline
		"------" newline
	]
]

; -- rules --------------------------------------------------------------------
global-signature: #{504B0102}
local-signature: #{504B0304}
central-signature: #{504B0506}

crc: orig-size: comp-size: name-size: filedate:
start: mark: offset: comment: version: flags:
comp-size: orig-size: extra-size: comment-size: comment:
comp: zip-files: filename: date: time: extrafield: metadata: 
name-size: local-name-size: filename: raw-filename: local-filename: raw-local-filename:
	none

extra-rule: [
	(extra-name: none)
	[
		if (not zero? extra-size) 
		; TODO: Support other extra types
		copy type extra-unicode-path [
			copy size 2 skip (size: (load-number size) - 5) ; NOTE: total size of version + crc + text
			copy extra-version skip ; NOTE: should be 1
			copy extra-crc 4 skip
			copy extra-name size skip
			(filename: load-dos-path to string! extra-name)
		]
	|	none
	]
]

size-rule: [
	copy comp-size 4 skip (comp-size: load-number comp-size)
	copy orig-size 4 skip (orig-size: load-number orig-size)
	copy name-size 2 skip (name-size: load-number name-size)
	copy extra-size 2 skip (extra-size: load-number extra-size)
]

file-action: quote (
	filename: global-entry/filename
	zip-files/:filename: switch global-entry/method [
		store	[comp]
		deflate	[decompress/deflate comp orig-size]
	]
	date: global-entry/date
	date/time: global-entry/time
	metadata/:filename: context compose [
		date: (date)
		extra: (extrafield)
	]
	info file-info
	global-headers/:filename: global-entry
	local-headers/:filename: local-entry
)

file-info: [
	newline
	"GFile " filename #"(" name-size #"/" length? filename #")" newline
	"GRaw: " raw-filename newline
	"LFile:" local-filename #"(" name-size #"/" length? local-filename #")" newline
	"LRaw: " raw-local-filename newline
	"Size: " comp-size #"/" orig-size #"/" to percent! round/to comp-size * 1.0 / orig-size 0.01% newline
	"Method:" method newline
	"Date: " date newline
	"Extra:" extrafield newline
	"Comment:" comment newline
	"-------------------------" newline
]

local-header: [
	local-signature
	copy version 2 skip ; version
	copy flags 2 skip ; flags
	copy method 2 skip ; compression
	copy time 2 skip ; mod. time
	copy date 2 skip ; mod- date
	copy crc 4 skip ; crc32
	size-rule
	copy filename name-size skip 
	extra-rule
	(
		print ["LOCL Xsize:" extra-size]
		print ["-locl-EXTRA:" extra-name]
		local-entry: context compose [
			version:	(version)
			flags:		(flags)
			method:		(select [0 'store 8 'deflate] load-ishort method)
			crc:		(crc)
			time:		(load-msdos-time time)
			date:		(load-msdos-date date)
			raw-filename: (filename)
			filename:	(to file! filename)
			comp-size:	(comp-size)
			orig-size:	(orig-size)
			name-size:	(name-size)
			extra-size:	(extra-size)
		]
	)
	copy comp comp-size skip
]

global-header: [
	global-signature
	copy version 4 skip	; versions
	copy flags 2 skip	; flags
	copy method 2 skip
	copy time 2 skip
	copy date 2 skip
	copy crc 4 skip	; crc
	size-rule
(print "aft size")
	copy comment-size 2 skip (comment-size: load-number comment-size)
	8 skip	; TODO: various attributes
	copy offset 4 skip (offset: load-number offset)
	copy filename name-size skip
	extra-rule
	copy comment comment-size skip
	(
		print ["GLOB Xsize:" extra-size]
		print ["-glob-EXTRA:" extra-name]
		; TODO: add error handling for unsupported methods
		global-entry: context compose [
			version:	(version)
			flags:		(flags)
			method:		(select [0 'store 8 'deflate] load-ishort method)
			crc:		(crc)
			time:		(load-msdos-time time)
			date:		(load-msdos-date date)
			raw-filename: (filename)
			filename:	(to file! filename)
			comment:	(comment)
			comp-size:	(comp-size)
			orig-size:	(orig-size)
			name-size:	(name-size)
			extra-size:	(extra-size)
		]
	)
]

entry-rule: [
	global-header
	mark:
	(start: skip head start offset)
	:start
	local-header
	(
		probe local-entry
		probe global-entry
	)
	file-action
	:mark
]

; -- support debug functions --------------------------------------------------

set 'parse-central-signature func [
	value [binary!]
	/local disk-nr disk-cdir entries disk-entries cd-length arc-size comment-len comment
][
	parse value [
		thru central-signature
		copy disk-nr 2 skip
		copy disk-cdir 2 skip
		copy entries 2 skip
		copy disk-entries 2 skip
		copy cd-length 4 skip
		copy arc-size 4 skip
		copy comment-len 2 skip
		(comment-len: load-ishort comment-len)
		copy comment comment-len skip
	]
	print [
		"Disk number and central dir:" load-ishort disk-nr load-ishort disk-cdir newline
		"Entries and disk entries   :" load-ishort entries load-ishort disk-entries newline
		"Central dir size           :" load-ishort cd-length newline
		"Archive size               :" load-ishort arc-size newline
		"Comment                    :" comment
	]
]

set 'parse-global-signature func [
	value [binary!]
	/local
][
	parse value [
		thru global-signature
		copy version 4 skip	; versions
		copy flags 2 skip	; flags
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
		copy filename name-size skip (filename: to file! raw-filename: filename)
		copy extrafield extra-size skip
		copy comment comment-size skip
	]
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
	foreach file files [
		entry: make-entry strip-path file
		; write file offset in archive
		change skip entry/2 42 to-ilong arc-size
		; directory entry
		append central-directory entry/2
		; compressed file + header
		append archive entry/1
		arc-size: arc-size + length? entry/1
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
	/verbose
][
	if verbose [verbose?: true]
	zip-files: copy #()
	metadata: copy #()
	local-headers: copy #()
	global-headers: copy #()
	parse data [
		start:
		some [to local-signature]
		to global-signature
		some entry-rule
	]
	either meta [reduce [zip-files metadata]][zip-files]
]

; -- file functions ---------------------------------------------------------------

set 'zip func [
	"Save ZIP archive created from given files or paths"
	where [file!]	"Where to save"
	files [file! block!]	"File(s) and/or path(s) to archive"
	/local grab-files out
][
	grab-files: func [path /local files][
		either dir? path [
			files: read path
			append out path
			foreach file files [
				grab-files rejoin [path file]
			]
		][
			append out path
		]
	]
	
	files: append copy [] files
	out: copy []
	foreach file files [grab-files file]
	write/binary where make-zip out
	out
]

set 'unzip func [
	"Extract files from ZIP archive"
	value [file!]	"ZIP archive to extract"
	/local data file content out
][
	out: copy []
	data: load-zip read/binary value
	foreach [file content] data [
		append out file
		either dir? file [
			make-dir/deep file
		][
			write/binary file content
		]
	]
	out
]

; -- end of context
]
