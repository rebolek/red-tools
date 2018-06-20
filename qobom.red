Red[
	Title: "QOBOM - Query over block of maps"
	Author: "Boleslav Březovský"
	Usage: {
keep <column> where
<column> is <value>
<column> contains <value>
<column> matches <parse rule>
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
;	/local
;		name-rule room-rule match-rule
;		conditions value selector
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
	keep-rule: [
		; TODO: support multiple selectors
		'keep
		set selector [block! | lit-word! | lit-path!]
		'where
	]

	parse dialect [
		opt keep-rule
		some [
			col-rule
		|	find-rule
		|	match-rule
		]
	]

	collect [
		foreach item data [
			if all conditions [
				keep switch type?/word selector [
					none! [item]
					lit-word! lit-path! [select-deep item to path! selector]
					block! [
						collect [
							foreach key selector [keep select-deep item to path! key]
						]
					]
				]
			]
		]
	]
]
