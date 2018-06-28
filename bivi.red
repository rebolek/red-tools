Red[
	Name: "BiVi - binary viewer"
	Author: "Boleslav Březovský"
]

do https://rebolek.com/redquire
redquire 'ansi-seq


bivi!: context [
	data: none
	lines-per-page: 8 ; how many lines per page
	line: 0
	addout: []
	mark-start: 0
	mark-end: 0
	last-match: none
	pattern: none
	numbers: charset "1234567890"

	print-page: func [
		line
		/local value ret
	][

		infoline: reduce [
			'cls
			'at 1x1 "Data length: " 'bold form length? data 'reset " | Page:" form line / lines-per-page "/" form (length? data) / lines-per-page space
		]
		append infoline addout
		append infoline "^/"
		ansi/do infoline
		repeat j lines-per-page [
			ansi/do print-line data line - 1 + j * 16
		]
		ret: line
		parse ask ":" [
			#"q" (ret: none)
		|	#"f" (ret: line + lines-per-page) ; TODO: limit at maximum ; NEXT PAGE - default action
		|	#"b" (ret: max 0 line - lines-per-page) ; PREV PAGE - line was already updated, so subtract it twice
		|	#"/" copy pattern to end (last-match: none ret: find-pattern) ; FIND <pattern>
		|	#"n" (ret: find-pattern) ; FIND NEXT
		|	#"l" copy value some numbers (lines-per-page: to integer! value) ; SET LINES PER PAGE
		]
		ret
	]
	print-line: func [
		"return line of 16 values"
		data position
		/local line
	][
		line: copy/part at data position 16
		bin-part: copy []
		char-part: copy []
		repeat i 16 [
			char: to integer! line/:i
			if all [
				not zero? mark-start
				(position + i - 1) >= mark-start
				(position + i - 1) <= mark-end
			][
				append bin-part 'bold
				append char-part 'bold
			]
			append bin-part rejoin [form to-hex/size char 2 space]
			append char-part case [
				all [char > 31 char < 128][form to char! char]
				any [char = 10 char = 13]["↵"]
				char = 9 ["⇥"]
				'default [dot]
			]
			append bin-part 'reset ; TODO: reset only when needed
			append char-part 'reset
			if i = 8 [
				append bin-part space
				append char-part space
			]
		]
		t: compose [(form to-hex/size position 4) " | " (bin-part) "| " (char-part) "^/"]
	]
	find-pattern: func [
	][
		index: line + 1
		unless last-match [last-match: data]
		either mark: find last-match pattern [
			last-match: next mark
			mark-start: index? mark
			mark-end: -1 + (index? mark) + length? pattern
			index: (index? mark) / 16
			addout: reduce  ['bold pattern 'reset space "found at line" space 'bold form index 'reset]
		][
			index: line
			if pattern [addout: reduce ['bold pattern 'reset space "not found." 'reset]]
		]
		index
	]
	set 'bivi func [file][
		data: file
		if file? data [data: read/binary data] ; TODO: support url! also?
		pages: (length? data) / lines-per-page
		unless zero? (length? data) // lines-per-page [pages: pages + 1]
		until [
			none? line: print-page line
		]
	]
]
