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
	steps: 0
	internal?: no

	on-deep-change*: func [
		owner word target action new index part
		/local mark
	][
		probe action
		if word = 'data [
			switch action [
				insert append [
					if any [
						not block? new
						odd? length? new
					][
						do make error! "Invalid data"
					]
					if mark: find data new/1 [
						owner/internal?: true
						remove mark
					]
				]
				inserted appended [
					sort/skip/compare data 2 1 ; sort lexicographically first
					sort/skip/compare data 2 2 ; then sort by score
				]
				remove [
					if zero? steps [owner/steps: part * 2]
				]
				removed [
					unless zero? owner/steps [
						remove data
						owner/steps: owner/steps - 1
					]
				]
				poke [
			;		do make error! "Action not supported"
					print [#poke index new]
				]
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


test: [
	s: make-sorted-set
	append s [a 5]
	append s [b 3]
	append s [c 1]
	append s [d 4]
]
