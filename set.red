Red[]

set!: object [
	data: []

	on-deep-change*: func [
		owner word target action new index part
		/local mark
	][
		all [
			word = 'data 
			find [poke insert append] action
			mark: find data new
			remove mark
		]
	]
]

make-set: func [/local value][
	value: make set! []
	value/data
]
