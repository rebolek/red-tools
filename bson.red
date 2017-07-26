Red [
	Title: "BSON"
	Author: "Boleslav Březovský"
]

; Types:

; byte 	1 byte (8-bits)
; int32 	4 bytes (32-bit signed integer, two's complement)
; int64 	8 bytes (64-bit signed integer, two's complement)
; uint64 	8 bytes (64-bit unsigned integer)
; double 	8 bytes (64-bit IEEE 754-2008 binary floating point)
; decimal128 	16 bytes (128-bit IEEE 754-2008 decimal floating point)

; document 	::= 	int32 e_list "\x00" 	BSON Document. int32 is the total number of bytes comprising the document.

load-int: func [s e] [to integer! reverse copy/part s e]

name=: value=: none

byte: [skip]
int32: [s: 4 byte e:]
int64: [8 byte]
uint64: [8 byte]
double: [8 byte]
decimal128: [16 byte]

null-byte: #"^(00)"
string-byte: complement charset null-byte

document: [s: int32 e: (print ["doc length" load-int s e]) collect e-list null-byte]

;e_list 	::= 	element e_list 	
;	| 	"" 	

e-list: [
	some [
		element 
		keep (to set-word! to string! name=) 
		keep (value=)
		(print ["elem:" mold copy/part s e])
	]
]

element: [
	#"^(01)" e-name double     ; 64-bit binary FP
|	#"^(02)" e-name string	   ; UTF-8 string
|	#"^(03)" e-name document   ; Embedded document
|	#"^(04)" e-name document   ; Array
|	#"^(05)" e-name binary     ; Binary data
|	#"^(06)" e-name Undefined  ; Deprecated
|	#"^(07)" e-name 12 byte    ; ObjectId
|	#"^(08)" e-name #"^(00)"   ; Boolean "false"
|	#"^(08)" e-name #"^(01)"   ; Boolean "true"
|	#"^(09)" e-name int64      ; UTC datetime
|	#"^(0A)" e-name            ; Null value
|	#"^(0B)" e-name cstring cstring   ; Regular expression - The first cstring is the regex pattern, the second is the regex options string. ;Options are identified by characters, which must be stored in alphabetical order. Valid options are 'i' for case insensitive matching, 'm' ;for multiline matching, 'x' for verbose mode, 'l' to make \w, \W, etc. locale dependent, 's' for dotall mode ('.' matches everything), and ;'u' to make \w, \W, etc. match unicode.
|	#"^(0C)" e-name string 12 byte    ; DBPointer — Deprecated
|	#"^(0D)" e-name string     ; JavaScript code
|	#"^(0E)" e-name string     ; Symbol. Deprecated
|	#"^(10)" (print "integer") e-name int32 (value=: load-int s e)      ; 32-bit integer
|	#"^(11)" e-name uint64     ; Timestamp
|	#"^(12)" e-name int64      ; 64-bit integer
|	#"^(13)" e-name decimal128 ; 128-bit decimal floating point
|	#"^(FF)" e-name            ; Min key
|	#"^(7F)" e-name            ; Max key
]

; TODO: where length is set, use that length in rule instead of SOME 

e-name: [cstring (name=: copy/part s e)]              ; Key name
string: [int32 s: some byte e: null-byte] ; String - The int32 is the number bytes in the (byte*) + 1 (for the trailing '\x00'). The (byte*) is zero or more UTF-8 encoded characters.
cstring: [s: some string-byte e: null-byte (print ["cstring" to string! copy/part s e])] ; Zero or more modified UTF-8 encoded characters followed by '\x00'. The (byte*) MUST NOT contain '\x00', hence it is not full UTF-8.
binary: [int32 subtype s: some byte e:] ; Binary - The int32 is the number of bytes in the (byte*).
subtype: [
	#"^(00)"                   ; Generic binary subtype
|	#"^(01)"                   ; Function
|	#"^(02)"                   ; Binary (Old)
|	#"^(03)"                   ; UUID (Old)
|	#"^(04)"                   ; UUID
|	#"^(05)"                   ; MD5
|	#"^(80)"                   ; User defined
]
code-w-s: [int32 string document] ; Code w/ scope

decode: func [data] [
	parse data document
]