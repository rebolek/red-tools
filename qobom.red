Red[
	Title: "QOBOM - Query over block of maps"
	Author: "Boleslav Březovský"
	Usage: {
```
keep [ <key> or * ] where
	<key> is <value>
	<key> [ = < > <= >= ] <value>
	<key> contains <value>
	<key> matches <parse rule>
```

<value> can be `paren!` and then is evaluated first
<value> can be `block!` and then is interpred as list of values that can match

Support for expressions in count - see following example:

>> qobom messages [keep ['author 'text] as map where 'sent > (now - 6:0:0) count by 'author (length? text)]
== #(
    "pekr" 1999
    "9214" 116
    "BeardPower" 69
)

NOTE: expression must return number to be counted (probably should add some checks)


	}
]

qobom!: context [
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

sort-by: func [
	"Sort block of maps"
	data
	match-key
;	keep-key ; TODO: support * for keeping everything 
;	TODO: sorting order
	/local result value
][
;	NOTE: How expensive is map!->block!->map! ? Is there other way?
	result: clear #()
	foreach item data [
		value: item/:match-key
		result/:value: either result/:value [
			result/:value + 1
		][
			1
		]
	]
	to map! sort/skip/compare/reverse to block! result 2 2
]

do-conditions: func [
	data conditions selector type
	/local value
][
	type: equal? map! type
	collect [
		foreach item data [
			if any conditions [
				case [
					equal? '* selector 	[keep/only either type [item][values-of item]]
					block? selector		[
						value: to map! collect [foreach s selector [keep reduce [s select-key item s]]]
						keep/only either type [value][values-of value]
					]
					'default			[
						value: select-key item selector
						keep either type [to map! reduce [selector value]][value]
					]
				]
			]
		]
	]
]

select-key: func [item selector][
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

count-values: func [
	"Count occurences of each value in DATA. Return map! with values as keys and count as values"
	data
	/key 
		name "Key to match"
		action
	; TODO: support some refinement to return block! instead (or make it default?)
	/local result act-result 
][
	result: copy #()
	foreach value data [
		either key [
			; NOTE: I'm doing some black magic here to simplify the dialect
			;		It's certainly not the fastest way and should be redone
			act-result: do bind as block! action make object! to block! value
			key-name: value/:name
			result/:key-name: either result/:key-name [result/:key-name + act-result][act-result]
		][
			result/:value: either result/:value [result/:value + 1][1]
		]
	]
	to map! sort/skip/compare/reverse to block! result 2 2
]

add-condition: func [
	condition
][
	append group condition
]

value-rule: [
	set value skip (
		if paren? value [value: compose value]
	)
]

col-rule: [
	set key [lit-word! | lit-path!]
	[
		'is 'from set value block! (
			add-condition compose/deep [
				find [(value)] select-deep item (key)
			]
		)
	|	['is | '=] value-rule (
			add-condition compose [
				equal? select-deep item (key) (value)
			]
		)
	|	set symbol ['< | '> | '<= | '>=] value-rule (
			add-condition compose [
				(to paren! reduce ['select-deep 'item key]) (symbol) (value)
			]
		)
	]
]
find-rule: [
	set key [lit-word! | lit-path!]
	'contains
	value-rule (
		add-condition compose [
			find select-deep item (key) (value)
		]
	)
]
match-rule: [
	set key [lit-word! | lit-path!]
	'matches
	value-rule (
		append value [to end]
		add-condition compose/deep [
			parse select-deep item (key) [(value)]
		]
	)
]
keep-rule: [
	(keep-type: block!)
	'keep
	set selector ['* | block! | lit-word! | lit-path!]
	opt ['as 'map (keep-type: map!)]
	'where
]
sort-rule: [
	'sort 'by set value skip (
		sort-by result value
	)
]
count-rule: [
	'count (count-by?: no)
	opt [
		'by (count-by?: yes)
		set key lit-word!
		set value paren!
	]
	(
		result: either count-by? [
			count-values/key result key value
		][
			count-values result
		]
	)
]
conditions-rule: [col-rule | find-rule | match-rule]
do-cond-rule: [(
	repend conditions ['all group]
	result: do-conditions data-block conditions selector keep-type
)]

conditions: []
group: none
data-block: none
result: none
value: none
key: none

set 'qobom func [
	"Simple query dialect for filtering messages"
	data
	dialect
	/local
		selector
		keep-type count-by?
][
	data-block: data
	clear conditions 
	value: result: none
	group: copy []

	parse dialect [
		keep-rule
		conditions-rule
		any [
			['and conditions-rule]
		|	[
				'or (
					repend conditions ['all group]
					group: copy []
				)
				conditions-rule
			]
		]
		do-cond-rule
		opt count-rule
	]
	result
]
; -- end of context
]
