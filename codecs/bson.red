Red[
	Notes: [
		"INT64, UINT64 and DEC128 are kept as binary!"
	]
]


path: %../libbson/tests/binary/

bson: context [

	output: copy #()
	target: output
	stack: copy []
	name-stack: copy []

	name: value: none
	length: doc-length: 0

	emit: quote (put target name value)
	; TODO: Is this a proper way to decode date?
	load-date: func [][value: to date! to integer! copy/part value 4]

	byte:	[copy value skip]
	i32:	[copy value 4 skip (value: to integer! reverse value)]
	i64:	[copy value 8 skip]
	u64:	[copy value 8 skip]
	double:	[copy value 8 skip (value: to float! reverse value)]
	decimal128: [copy value 16 skip]

	null: #"^@"
	char: charset reduce ['not null]
	c_string: [copy value to null skip]
	string: [
		i32 (length: value - 1)
		copy value length skip
		null
		(value: to string! value)
	]
	binary: [
		i32 (length: value)
		subtype
		copy value length skip
	]
	subtype: [
		#"^(00)" (bin-type: 'generic)
	|	#"^(01)" (bin-type: 'function)
	|	#"^(02)" (bin-type: 'binary-old)
	|	#"^(03)" (bin-type: 'uuid-old)
	|	#"^(04)" (bin-type: 'uuid)
	|	#"^(05)" (bin-type: 'md5)
	|	#"^(06)" (bin-type: 'encrypted-bson-value)
	]

	; FIXME: This naive set-word conversion may fail on more complicated keys
;	e_name: [c_string (name: probe to set-word! to string! value)]
	e_name: [c_string (name: probe to string! value)]

	document: [
		i32 (doc-length: value)
		(print ["DOC LEN:" doc-length])
		some [t: (probe t) element]
		null
	]

	sub-doc: [
		(insert stack target)
		(target: copy #())
		e_name
		(insert name-stack name)
		document
		(name: take name-stack)
		(value: target)
		(target: take stack)
		emit
	]

	element: [
		#"^(01)" e_name double emit		; 64bit float
	|	#"^(02)" e_name string emit		; UTF-8 string
	|	#"^(03)" sub-doc				; embedded doc
	|	#"^(04)" sub-doc				; array
	|	#"^(05)" e_name binary emit		; binary data
	; #"^(06)" - deprecated
	|	#"^(07)" e_name copy value 12 skip emit			; object-id
	|	#"^(08)" e_name #"^(00)" (value: false) emit	; logic TRUE
	|	#"^(08)" e_name #"^(01)" (value: true) emit		; logic FALSE
	|	#"^(09)" e_name i64 (load-date) emit			; UTC datetime
	|	#"^(0A)" e_name (value: none) emit				; null value
	|	#"^(0B)" e_name
		c_string (pattern: value)
		c_string (options: value)
		; TODO: emit
	; #"^(0C)" - deprecated
	|	#"^(0D)" e_name string emit		; JS code
	; #"^(0E)" - deprecated
	; #"^(0F)" - deprecated
	|	#"^(10)" e_name i32 emit		; 32bit integer
	|	#"^(11)" e_name u64 emit		; timestamp
	|	#"^(12)" e_name i64 emit		; 64bit integer
	|	#"^(13)" e_name decimal128 emit	; 128bit decimal FP
	|	#"^(FF)" e_name					; min key - TODO: emit
	|	#"^(7F)" e_name					; max key - TODO: emit

	]

	init: does [
		output: copy #()
		target: output
		stack: copy []
	]

	set 'load-bson func [data [binary! file!]] [
		if file? data [data: read/binary data]
		init
		probe parse data document
		output
	]

]
