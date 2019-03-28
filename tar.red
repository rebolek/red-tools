Red[]

tar!: context [

	make-checksum: func [data /local result][
		result: 0
		data: copy/part data 148
		append/dup data #" " 8
		foreach byte data [result: result + to integer! byte]
		result
	]

	load-octal: func [
		data
	;	/local result mult
	][
		mult: 1
		result: 0
		foreach digit reverse copy data [
			result: result + (mult * to integer! form digit)
			try [mult: mult * 8]
		]
		result
	]

	load-bin: func [binary][
		binary: to string! binary
		take/last binary
		binary
	]

	get-type: func [type][
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
			"Checksum: " checksum tab computed-checksum tab checksum - computed-checksum newline
			"Link ind: " link-indicator newline
			"Linkfile: " linked-filename newline
			"Owner nm: " owner-name newline
			"Group nm: " group-name newline
			"Devmajor: " device-major-number newline
			"Devmijor: " device-minor-number newline
			"Fileprfx: " filename-prefix newline
		]
	]

	set 'untar func [
		data
		/local
	;		filename filemode owner-id group-id filesize
	][
		files: #()

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
			copy checksum 8 skip
			(
				checksum: load-bin checksum
				take/last checksum  ; remove space at end
				checksum: load-octal checksum
				computed-checksum: make-checksum header-start
			)
		]
		link-indicator-rule: [
			copy link-indicator skip
			(link-indicator: switch/default load-bin link-indicator ["1" ['hard] "2" ['symbolic]]['normal])
		]
		ustar-rule: [
			#{757374617220} ;"ustar "
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
		;	(size: probe either zero? filesize [12][filesize])
			i: (pad: 513 - ((index? i) // 512))
			pad skip
			copy content filesize skip x:
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
			t1:
			filename-prefix-rule
			t2:
			(print-file-info)
			; ---
			filedata-rule
			t:
		]

		parse data [
			some [
				2 empty-block to end
			|	file-rule
			]
		]

	;	print-file-info
		files
	]

]

