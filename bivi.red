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
		/local value ret count
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
		count: 1
		count-rule: [
			(count: 1 value: none)
			copy value any numbers
			(unless empty? value [count: to integer! value])
		]
		main-rule: [
			#"q" (ret: none)
		|	#"e" count-rule (ret: line + count) ; NEXT lINE ; TODO - check max value
		|	#"y" count-rule (ret: max 0 line - count) ; PREV LINE
		|	#"f" count-rule (ret: lines-per-page * count + line ) ; TODO: limit at maximum ; NEXT PAGE - default action
		|	#"b" count-rule (ret: max 0 line - ( * countlines-per-page)) ; PREV PAGE - line was already updated, so subtract it twice
		|	#"/" copy pattern to end (last-match: none ret: find-pattern) ; FIND <pattern>
		|	#"n" (ret: find-pattern) ; FIND NEXT
		|	#"l" copy value some numbers (lines-per-page: to integer! value) ; SET LINES PER PAGE
		|	#"h" (print-help)
		]
		parse ask ":" main-rule
		ret
	]
	print-line: func [
		"return line of 16 values"
		data position
		/local line hilite?
	][
		hilite?: false
		line: copy/part at data position 16
		bin-part: copy []
		char-part: copy []
		repeat i 16 [
			char: to integer! line/:i
			; -- highlight mark
			if all [
				not zero? mark-start
				(position + i - 1) >= mark-start
				(position + i - 1) <= mark-end
			][
				; TODO: turn on hilite only on mark start
				hilite?: true
				append bin-part 'inverse
				append char-part 'inverse
			]
			; -- add character
			append bin-part rejoin [form to-hex/size char 2 space]
			append char-part case [
				all [char > 31 char < 128][form to char! char]
				any [char = 10 char = 13]["↵"]
				char = 9 ["⇥"]
				'default [dot]
			]
			; -- end highlighting
			if hilite? [
				; TODO: turn off hilite only after mark end
				append bin-part 'reset
				append char-part 'reset
				hilite?: false
			]
			if i = 8 [
				append bin-part space
				append char-part space
			]
		]
		compose [(form to-hex/size position 4) " | " (bin-part) "| " (char-part)]
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
	print-help: does [
		ansi/do [
			cls
			at 1x1
			bold "^-NAVIGATION^/^/" reset
			"Navigation commands can be followed by numbers to skip more lines/pages.^/"
			bold "f^-ENTER" reset "^-next page^/"
			bold "b" reset "^-^-previous page^/"
			bold "e" reset "^-^-next line^/"
			bold "y" reset "^-^-previous line^/^/"
			bold "/" reset "<pattern>" "^-search for <pattern>^/"
			bold "n" reset "^-^-repeat previous search^/"
			"^/^/Press ENTER to continue^/"
		]
		input
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
