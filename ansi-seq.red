Red [
	To-Do: "Write dialect that will be converted to `print-seq` format"
]

ansi: context [

esc-main: #{1B5B} ; ESC+[
clear-screen: append copy esc-main "2J"

print-esc: func [data][foreach char data [prin to char! char]]
print-seq: func [
	"Print combination of text and ANSI sequences"
	data [block!] "Block of binary! and string! values"
][
	foreach value data [
		switch type?/word value [
			string! [prin value]
			binary! [print-esc value]
		]
	]
]

set-position: func [position][
	rejoin [esc-main form position/x #";" form position/y #"H"]
]

demo: does [
	do [cls at 1x1 fg red "Welcome to " fg black bg white "A" bg yellow "N" bg red "S" bg magenta "I" reset bold underline " console" reset]
]

colors: [black red green yellow blue magenta cyan white none default]

as-rule: func [block][
	block: collect [
		foreach value block [keep reduce [to lit-word! value '|]]
	]
	also block take/last block
]

colors-list: as-rule colors

do: func [
	data
	/local value type
		move-rule
		color-rule
		style-rule
][
	append data 'reset
	color-rule: compose/deep [
		set type ['fg | 'bg]
		set value [(colors-list)]
		keep (to paren! [
			type: form pick [3 4] equal? 'fg type
			value: 47 + index? find colors value
			rejoin [esc-main type value #"m"]
		])
	]
	move-rule: [
		(value: 1)
		set type ['up | 'down | 'left | 'right]
		opt [set value integer!]
		keep (rejoin [esc-main form value #"@" + index? find [up down left right] type])
	]
	style-rule: [
		set type ['bold | 'italic | 'underline]
		keep (rejoin [esc-main form index? find [bold none italic underline] type #"m"])
	]

	print-seq parse data [
		collect [
			some [
				'reset keep (rejoin [esc-main "0m"])
			|   'cls keep (clear-screen)

			|   style-rule
			|   move-rule
			|   color-rule

			|   'at set value pair! keep (probe set-position value)
		;    |    set type ['fg | 'bg] set value word! keep (set-color type value)
			|   keep string!
			]
		]
	]
]

; -- end of context
]