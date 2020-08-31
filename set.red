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

sorted-set!: object [
	data: []

	on-deep-change*: func [
		owner word target action new index part
		/local mark
	][
		if word = 'data [
			if find [poke insert append] action [
				if mark: find data new/1 [remove/part mark 2]
			]
			if find [inserted appended] action [
				sort/skip/compare data 2 2
			]
		]
	]
]

make-set: func [/local value][
	value: make set! []
	value/data
]

make-sorted-set: func [/local value][
	value: make sorted-set! []
	value/data
]

