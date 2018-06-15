Red[]

query: func [
	"Simple query dialect for filtering messages"
	dialect
	/local
		name-rule room-rule match-rule
		value
][
	conditions: clear []
	value: none

	name-rule: ['name ['is | '=] set value string! (
		append conditions compose [equal? message/fromUser/username (value)]
	)]
	room-rule: ['room ['is | '=] set value string! (
		append conditions compose [equal? message/room-name (value)]
	)]
	match-rule: [set value string!(
		append conditions compose [find message/text (value)]
	)]

	parse dialect [
		some [
			name-rule
		|	room-rule
		|	match-rule
		]
	]

	collect [
		foreach message messages [
			if all conditions [keep message]
		]
	]
]
