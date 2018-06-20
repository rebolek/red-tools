Red[
	Title: "QOBOM - Query over block of maps"
	Author: "Boleslav Březovský"
	Usage: {
<column> is <value>
<column> contains <value>
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

qobom: func [
	"Simple query dialect for filtering messages"
	data
	dialect
	/local
		name-rule room-rule match-rule
		value
][
	conditions: clear []
	value: none

	col-rule: [
		set column [lit-word! | lit-path!]
		['is | '=]
		set value skip (
			append conditions compose [
				equal? select-deep item (column) (value)
			]
		)
	]
	find-rule: [
		set column [lit-word! | lit-path!]
		'contains
		set value skip (
			append conditions compose [
				find select-deep item (column) (value)
			]
		)
	]
	match-rule: [
		set column [lit-word! | lit-path!]
		'matches
		set value skip (
			append conditions compose/deep [
				parse select-deep item (column) [(value)]
			]
		)
	]


	parse dialect [
		some [
			col-rule
		|	find-rule
		|	match-rule
		]
	]

	collect [
		foreach item data [
			if all conditions [keep item]
		]
	]
]
