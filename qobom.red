Red[
	Title: "QOBOM - Query over block of maps"
	Author: "Boleslav Březovský"
	Usage: {
```
keep [ <column> or * ] where
	<column> is <value>
	<column> [ = < > <= >= ] <value>
	<column> contains <value>
	<column> matches <parse rule>
```

<value> can be `paren!` and then is evaluated first
<value> can be `block!` and then is interpred as list of values that can match
	}
]

select-deep: func [
	series
	value
][
	either word? value [
		select series value
	][
		; path
		foreach elem value [
			series: select series elem
		]
	]
]

; TODO: support `sobom` directly from `qobom ;(and rename it)
sobom: func [
	"Sort block of maps"
	data
	match-column
;	keep-column ; TODO: support * for keeping everything 
;	TODO: sorting order
	/local result value
][
;	NOTE: How expensive is map!->block!->map! ? Is there other way?
	result: clear #()
	foreach item data [
		value: item/:match-column
		result/:value: either result/:value [
			result/:value + 1
		][
			1
		]
	]
	to map! sort/skip/compare/reverse to block! result 2 2
]

qobom: func [
	"Simple query dialect for filtering messages"
	data
	dialect
;	/local
;		name-rule room-rule match-rule
;		conditions value selector
][
	conditions: clear []
	value: none

	value-rule: [
		set value skip (
			print "composing value"
			if paren? value [value: compose value]
		)
	]

	col-rule: [
		set column [lit-word! | lit-path!]
		[
			'is 'from set value block! (
				append conditions compose/deep [
					find [(value)] select-deep item (column)
				]
			)
		|	['is | '=] value-rule (
				append conditions compose [
					equal? select-deep item (column) (value)
				]
			)
		|	set symbol ['< | '> | '<= | '>=] value-rule (
				append conditions compose [
					(to paren! reduce ['select-deep 'item column]) (symbol) (value)
				]
			)
		]
	]
	find-rule: [
		set column [lit-word! | lit-path!]
		'contains
		value-rule (
			append conditions compose [
				find select-deep item (column) (value)
			]
		)
	]
	match-rule: [
		set column [lit-word! | lit-path!]
		'matches
		value-rule (
			append value [to end]
			append conditions compose/deep [
				parse select-deep item (column) [(value)]
			]
		)
	]
	keep-rule: [
		; TODO: `keep` is filler just now, should probably do something
		; TODO: support multiple selectors
		'keep
		[
			set selector ['* | block! | lit-word! | lit-path!]
		]
		'where
	]

	parse dialect [
		opt keep-rule
		some [
			col-rule
		|	find-rule
		|	match-rule
		|	'and ; filler, so we can write [column contains something and column contains something-else] instead of [column contains something column contains something-else] (but both work)
		; TODO: add `OR` rule
		]
	]

	select-column: func [selector item][
		switch type?/word selector [
			none! [item]
			lit-word! lit-path! [select-deep item to path! selector]
			block! [
				collect [
					foreach key selector [keep select-deep item to path! key]
				]
			]
		]
	]

	collect [
		;probe conditions
		foreach item data [
			if all conditions [
				either equal? '* selector [
					keep/only item
				][
					keep select-column selector item
				]
			]
		]
	]
]
