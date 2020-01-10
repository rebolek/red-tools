Red[]

tar!: context [

	make-checksum: func [
		"Return TAR header checksum"
		data [binary!]
		/local result byte
	][
		result: 0
		foreach byte data [result: result + byte]
		result
	]

	to-octal: func [
		"Convert integer to octal value in TAR format"
		value [integer!]
		/local octal digit
	][
		octal: copy ""
		until [
			digit: value // 8
			insert octal form digit
			value: value - digit / 8
			value < 8
		]
		insert octal form value
		append octal #"^@"
		insert/dup octal #"0" 12 - length? octal
		octal
	]

	load-octal: func [
		"Convert octal in TAR format to integer"
		value [binary! string!]
		/local result mult digit
	][
		mult: 1
		result: 0
		replace/all value #"^@" ""
		replace/all value #" " ""
		foreach digit reverse copy value [
			result: result + (mult * to integer! form digit)
			try [mult: mult * 8]
		]
		result
	]

	load-bin: func [binary][
		"Convert binary text in TAR format to string"
		binary: to string! binary
		take/last binary
		binary
	]

	get-type: func [
		"Describe TAR file format"
		type [string!]  
	][
		switch/default [
			"1" ['hard]
			"2" ['symbolic]
			"3" ['character]
			"4" ['block]
			"5" ['directory]
			"6" ['FIFO]
			"7" ['contiguous-file]
			"g" ['global-ext-header]
			"x" ['ext-header]
			; TODO: "A" - "Z"
		]
	]

	print-file-info: does [
		print [
			"Filename: " mold filename newline
			"Filemode: " filemode newline
			"Owner ID: " owner-id newline
			"Group ID: " group-id newline
			"Filesize: " filesize newline
			"Mod.date: " modification-date newline
			"Checksum: " chksm tab "computed:" computed-checksum tab "diff:" chksm - computed-checksum newline
			"Link ind: " link-indicator newline
			"Linkfile: " linked-filename newline
			"Owner nm: " owner-name newline
			"Group nm: " group-name newline
			"Devmajor: " device-major-number newline
			"Devminor: " device-minor-number newline
			"Fileprfx: " filename-prefix newline
		]
	]

	number: name: filename: linked-filename: filesize: filename-prefix:
	filemode: owner-id: group-id: owner-name: group-name:
	modification-date:
	chksm: computed-checksum:
	link-indicator: ustar-version:
	device-major-number: device-minor-number:
	i: j: pad:
		none

	name-rule: [
		copy name 100 skip
		(name: load-bin name)
	]
	filename-rule: [
		name-rule
		(filename: first parse name [collect [keep to #"^@"]]) ; TODO: to file! ?
	]
	linked-filename-rule: [
		name-rule
		(linked-filename: name) ; TODO: to file! ?
	]
	filemode-rule: [
		copy filemode 8 skip
		(filemode: load-bin filemode)
	]
	owner-id-rule: [
		copy owner-id 8 skip
		(owner-id: load-bin owner-id)
	]
	group-id-rule: [
		copy group-id 8 skip
		(group-id: load-bin group-id)
	]
	filesize-rule: [
		copy filesize 12 skip
		(filesize: load-octal load-bin filesize)
	]
	modification-date-rule: [
		copy modification-date 12 skip
		(modification-date: to date! load-octal load-bin modification-date)
	]
	checksum-rule: [
		copy chksm 8 skip
		(
			chksm: load-bin chksm
			take/last chksm ; remove space at end
			chksm: load-octal chksm
			computed-checksum: make-checksum header-start
		)
	]
	link-indicator-rule: [
		copy link-indicator skip
		(link-indicator: switch/default load-bin link-indicator ["1" ['hard] "2" ['symbolic]]['normal])
	]
	ustar-rule: [
		#{7573746172} [#"^@" | space] ;"ustar"
		copy ustar-version 2 skip
	]
	owner-name-rule: [
		copy name 32 skip
		(owner-name: load-bin name)
	]
	group-name-rule: [
		copy name 32 skip
		(group-name: load-bin name)
	]
	device-number-rule: [
		copy number 8 skip
		(device-major-number: load-bin number)
		copy number 8 skip
		(device-minor-number: load-bin number)
	]
	filename-prefix-rule: [
		copy name 155 skip
		(filename-prefix: load-bin name)
	]
	filedata-rule: [
		i: (pad: 513 - ((index? i) // 512))
		pad skip
		copy content filesize skip
		(files/:filename: content)
		j: (pad: (513 - ((index? j) // 512) // 512))
		pad skip
	]

	empty-block: [512 #"^@"]

	file-rule: [
		header-start:
		filename-rule
		filemode-rule
		owner-id-rule
		group-id-rule
		filesize-rule
		modification-date-rule
		checksum-rule
		link-indicator-rule
		linked-filename-rule
		ustar-rule
		owner-name-rule
		group-name-rule
		device-number-rule
		filename-prefix-rule
		(print-file-info)
		; ---
		filedata-rule
	]
	

	zeroes: func [count [integer!]][append/dup copy #{} #"^@" count]

	make-entry: func [
		filename [file!]
		/local
			entry empty name data size date username entry chksm
	][
		entry: copy #{}
		empty: zeroes 8
		name: zeroes 100
		data: read/binary filename
		size: to-octal length? data
		date: to-octal to integer! query filename
		username: rejoin [#{} "sony" zeroes 28] ; TODO: replace with real username later
		insert/dup size #"0" 12 - length? size ; filename
		change name filename
		entry: rejoin [
			#{}
			name
			{0000644^@}	; file mode (TODO: replace with real mode)
			{0001750^@}	; owner's numeric user ID (TODO: replace with real value)
			{0001750^@}	; group's numeric user ID (TODO: replace with real value)
			size	; file size
			date	; file modification date
			"        "			; checksum
			entry #{30}	; link type (0 - normal file, 1 - hard, 2 - soft)
			zeroes 100
			"ustar "
			#{2000}	; version
			username	; TODO: owner's name
			username	; TODO: owner's group
			zeroes 8	; TODO: device major number
			zeroes 8	; TODO: device minor number
			zeroes 155	; TODO: split filename when needed
			zeroes 12	; pad entry to be 512 bytes
		]
		; fix checksum
		chksm: skip to-octal make-checksum entry 4
		change chksm #"^@"
		change at entry 148 chksm ; 148 is checksum position in header
		; pad to record size (512 bytes)
		repend entry [
			data
			zeroes 512 - ((length? data) // 512)
		]
		entry

	]

	set 'load-tar func [
		data
		/verbose
;		/local
	;		filename filemode owner-id group-id filesize
	][
		files: #()
		parse data [
			some [
				2 empty-block to end
			|	file-rule (if verbose [print-file-info])
			]
		]
		files
	]

	set 'make-tar func [
		files [file! block!]
	][
		files: append copy [] files
		out: copy #{}
		foreach file files [
			append out make-entry file
		]
		append out zeroes 1024 ; two empty records
		padding: (length? out) // 10240
		append out zeroes 10240 - padding ; pad to 20 records
		out
	]

]

