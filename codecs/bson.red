Red[
	Notes: [
		"INT64, UINT64 and DEC128 are kept as binary!"
	]
	Todo: [
		"Test #10 - regex"
		"Test #24 - binary data"
		"Test #25 (and some others) - 06 - deprecated"
		"Test #40 (and some others) - error"
		"Test #52 - empty (shouldn't be)"
		"Test #55 - Invalid UTF8"
	]
]

as-bin: func [value] [lowercase enbase/base value 16]
char: func [value] [
	case [
		not value						[""]
		all [value > 31 value < 128]	[to char! value]
		'else							[#"."]
	]
]

xxd: func [value /local index line out text] [
	value: copy value
	index: 0
	until [
		line: take/part value 16
		out: rejoin [
			as-bin to binary! index
			": "
		]
		text: clear ""
		until [
			append text char line/1
			append text char line/2
			append out as-bin take/part line 2
			append out space
			empty? line
		]
		append/dup out space 51 - length? out
		print [out text]
		index: index + 16
		empty? value
	]
	exit
]



path: %../libbson/tests/binary/

bson: context [

	doc:
	output:
	target: none
	stack: copy []
	name-stack: copy []

	name: key: value: none
	length: doc-length: 0

	emit: none
	emit-red: quote (put target name value)
	; TODO: Is this a proper way to decode date?
	load-date: quote (value: to date! to integer! copy/part value 4)
	load-array: quote (value: values-of value)

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
	e_name: [c_string (name: to string! value)]

	document: [
		i32 (doc-length: value)
		(print ["DOC LEN:" doc-length])
		any [t: (probe t) element]
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
	;	emit
	]

	element: [
		#"^(01)" e_name double emit						; 64bit float
	|	#"^(02)" e_name string emit						; UTF-8 string
	|	#"^(03)" sub-doc emit							; embedded doc
	|	#"^(04)" sub-doc load-array emit				; array
	|	#"^(05)" e_name binary emit						; binary data
	; #"^(06)" - deprecated
	|	#"^(07)" e_name copy value 12 skip emit			; object-id
	|	#"^(08)" e_name #"^(00)" (value: false) emit	; logic TRUE
	|	#"^(08)" e_name #"^(01)" (value: true) emit		; logic FALSE
	|	#"^(09)" e_name i64 load-date emit				; UTC datetime
	|	#"^(0A)" e_name (value: none) emit				; null value
	|	#"^(0B)" e_name
		c_string (pattern: value)
		c_string (options: value)
		; TODO: emit
	; #"^(0C)" - deprecated
	|	#"^(0D)" e_name string emit						; JS code
	; #"^(0E)" - deprecated
	; #"^(0F)" - deprecated
	|	#"^(10)" e_name i32 emit						; 32bit integer
	|	#"^(11)" e_name u64 emit						; timestamp
	|	#"^(12)" e_name i64 emit						; 64bit integer
	|	#"^(13)" e_name decimal128 emit					; 128bit decimal FP
	|	#"^(FF)" e_name									; min key - TODO: emit
	|	#"^(7F)" e_name									; max key - TODO: emit

	]

	init-loader: does [
		output: copy #()
		target: output
		stack: copy []
		emit: :emit-red
	]

	set 'load-bson func [data [binary! file!]] [
		if file? data [data: read/binary data]
		init-loader
		parse data document
		output
	]

	init-emitter: does [
		output: copy #{}
	]

	emit-bson: func [value] [
		append output value
	]

	emit-string: func [value] [
		append output value
		append output null
	]

	emit-number: func [value] [
		append output reverse to binary! value
	]

	emit-key: does [emit-string form key]

	make-array: func [data /local array index value] [
		array: copy #()
		index: 0
		foreach value data [
			put array index value
			index: index + 1
		]
		array
	]

	emit-doc: func [data [map! object!]] [
		insert stack output
		init-emitter
		foreach key keys-of data [
			value: data/:key
			switch type?/word value [
				float! [
					emit #{01}
					emit-string form key
					emit-number value
				]
				string! file! url! tag! email! ref! [
					emit #{02}
					emit-key
					emit-string value
				]
				map! object! [
					emit #{03}
					emit-key
					emit-doc value
				]
				block! [
					emit #{04}
					emit-key
					; TODO: this is not very efficient as it makes temporary
					;		MAP! that is thrown away. Adding directly
					;		would be better but it would need some changes
					;		in the emitter's architecture.
					emit-doc make-array value
				]
				binary! [
					emit #{0500} ; TODO: Be able to select subtype
					emit-key
					emit value
				]
				integer! [
					emit #{10}
					emit-key
					emit-number value
				]
			]
		]
		append output null
		insert output reverse to binary! 4 + length? output
		print ["EMIT:" as-bin output]
		output: append take stack output
		output
	]

	set 'to-bson func [data [map! object!]] [
		emit: :emit-bson
		doc: copy #{}
		stack: copy []
		output: doc
		emit-doc data
		output
	]
]
