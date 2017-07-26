Red [
	Title: "BSON"
]

; Types:

; byte 	1 byte (8-bits)
; int32 	4 bytes (32-bit signed integer, two's complement)
; int64 	8 bytes (64-bit signed integer, two's complement)
; uint64 	8 bytes (64-bit unsigned integer)
; double 	8 bytes (64-bit IEEE 754-2008 binary floating point)
; decimal128 	16 bytes (128-bit IEEE 754-2008 decimal floating point)

; document 	::= 	int32 e_list "\x00" 	BSON Document. int32 is the total number of bytes comprising the document.

byte: [skip]
int32: [4 byte]
int64: [8 byte]
uint64: [8 byte]
double: [8 byte]
decimal128: [16 byte]

null-byte: #"^(00)"

document: [s: int32 e: e-list null-byte]

;e_list 	::= 	element e_list 	
;	| 	"" 	

e-list: [element e-list | ""] ; TODO: empty string here?

;element 	::= 	"\x01" e_name double 	64-bit binary floating point
;	| 	"\x02" e_name string 	UTF-8 string
;	| 	"\x03" e_name document 	Embedded document
;	| 	"\x04" e_name document 	Array
;	| 	"\x05" e_name binary 	Binary data
;	| 	"\x06" e_name 	Undefined (value) — Deprecated
;	| 	"\x07" e_name (byte*12) 	ObjectId
;	| 	"\x08" e_name "\x00" 	Boolean "false"
;	| 	"\x08" e_name "\x01" 	Boolean "true"
;	| 	"\x09" e_name int64 	UTC datetime
;	| 	"\x0A" e_name 	Null value
;	| 	"\x0B" e_name cstring cstring 	Regular expression - The first cstring is the regex pattern, the second is the regex options string. ;Options are identified by characters, which must be stored in alphabetical order. Valid options are 'i' for case insensitive matching, 'm' ;for multiline matching, 'x' for verbose mode, 'l' to make \w, \W, etc. locale dependent, 's' for dotall mode ('.' matches everything), and ;'u' to make \w, \W, etc. match unicode.
;	| 	"\x0C" e_name string (byte*12) 	DBPointer — Deprecated
;	| 	"\x0D" e_name string 	JavaScript code
;	| 	"\x0E" e_name string 	Symbol. Deprecated
;	| 	"\x0F" e_name code_w_s 	JavaScript code w/ scope
;	| 	"\x10" e_name int32 	32-bit integer
;	| 	"\x11" e_name uint64 	Timestamp
;	| 	"\x12" e_name int64 	64-bit integer
;	| 	"\x13" e_name decimal128 	128-bit decimal floating point
;	| 	"\xFF" e_name 	Min key
;	| 	"\x7F" e_name 	Max key

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
|	#"^(10)" e_name int32      ; 32-bit integer
|	#"^(11)" e_name uint64     ; Timestamp
|	#"^(12)" e_name int64      ; 64-bit integer
|	#"^(13)" e_name decimal128 ; 128-bit decimal floating point
|	#"^(FF)" e_name            ; Min key
|	#"^(7F)" e_name            ; Max key




]