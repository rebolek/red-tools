Red [
	Title: "Ansi sequence dialect"
	Author: "Boleslav Březovský"
	Usage: {
CLS       - clear screen
AT pair!  - put curspor at position
FG word!  - set foregroud to color
BG word!  - set background to color
BOLD      - set bold style
ITALIC    - set italic style
UNDERLINE - set underline style
UP        - move cursor up
DOWN      - move cursor down
LEFT      - move cursor left
RIGHT     - move cursor right
RESET     - reset all styles
	}
]

ansi: context [

esc-main: #{1B5B} ; ESC+[
clear-screen: append copy esc-main "2J"

print-esc: func [data][foreach char data [prin to char! char]]
print-seq: func [
	"Print combination of text and ANSI sequences"
	data [block!] "Block of binary! and string! values"
][
	set 't data
	foreach value data [
		switch type?/word value [
			string! [prin value]
			binary! [print-esc value]
		]
	]
]

set-position: func [position][
	rejoin [esc-main form position/y #";" form position/x #"H"]
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
	/local type value
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

			|   'at set value pair! keep (set-position value)
		;    |    set type ['fg | 'bg] set value word! keep (set-color type value)
			|   keep [string! | char!]
			]
		]
	]
]

vline: func [
	pos
	height
][
	collect [
		repeat i height [
			keep reduce ['at pos + (i * 0x1) "│"]
		]
	]
]

tui: func [
	data
	/local cmd value stack
		box-rule
][
	stack: []
	dialect: clear []
	box-rule: [
		(clear stack)
		'box
		set value pair! (append stack value)
		set value pair! (append stack value)
		(
			width: stack/2/x - stack/1/x - 1
			height: stack/2/y - stack/1/y - 1
			repend dialect ['at stack/1 + 1x0 append/dup copy "" #"─" width] 	; top line
			repend dialect ['at stack/1 + (height + 1 * 0x1) + 1x0 append/dup copy "" #"─" width] 	; bottom line
			append dialect vline probe stack/1 height
			append dialect vline stack/1 + 1x0 + (width * 1x0) height
			repend dialect ['at stack/1 "┌"] 							; top-left copner
			repend dialect ['at stack/1 + (width + 1 * 1x0) "┐"]		; top-right corner
			repend dialect ['at stack/1 + (height + 1 * 0x1) "└"]		; bottom-left copner
			repend dialect ['at stack/2 "┘"] 							; bottom-right copner
		)
	]
	parse data [
		some [
			box-rule
		]
	]
	dialect
]

; -- end of context
]