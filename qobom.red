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
time: none
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
						value: to map! collect [foreach s selector [keep reduce [s select-key item to lit-word! s]]]
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
select-key: func [
	"Deep select key"
	value
	key
	/local item elem
][
	item: either lit-path? key [
		item: value
		foreach elem key [item: select item elem]
		item
	][select value key]
]
clean-word: func [
	"Remove punctuation from a word"
	word
][
	; TODO clean punctuation only if it's last letter?
	parse word [
		some [
			change #"." ""
		|	change #"," ""
		|	change #"?" ""
		|	change #"." ""
		|	skip
		]
	]
	word
]
count-frequency: func [
	"Count frequency of keys or words in keys"
	type "BY for counting keys, IN for counting words in keys"
	key
	/local result
][
	result: #()
	switch type [
		by [
			foreach value data-block [
				item: select-key value key
				result/:item: either result/:item [
					result/:item + 1
				][1]
			]
		]
		in [
			foreach value data-block [
				set 'v value
				item: select-key value key
				foreach word split item space [
					word: clean-word word
					result/:word: either result/:word [
						result/:word + 1
					][1]
				]
			]
		]
	]
	result: make map! sort/skip/compare/reverse to block! result 2 2
]
add-condition: func [
	condition
][
	append group condition
]

lits: [lit-word! | lit-path!]
value-rule: [
	set value skip (
		if paren? value [value: compose value]
	)
]
reflector-rule: [
	(reflector: none)
	set value skip 'in (
		reflector: value
	)
]
col-rule: [
	opt reflector-rule
	set key lits
	[
		'is 'from set value block! (
			add-condition compose/deep [
				find [(value)] select-deep item (key)
			]
		)
	|	['is | '=] value-rule (
			either reflector [
				add-condition compose [
					equal? (to paren! compose [t: select-deep item (key)]) (value)
				]
			][
				add-condition compose [
					equal? select-deep item (key) (value)
				]
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
	set key lits
	'contains
	value-rule (
		add-condition compose [
			find select-deep item (key) (value)
		]
	)
]
match-rule: [
	set key lits
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
basic-rule: [
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
frequency-rule: [
	'frequency [
		set type ['by | 'in]
		set key lits
	]
	(count-frequency type key)
]
main-rule: [
	frequency-rule
|	basic-rule
]
conditions: []
group: none
data-block: none
result: none
value: none
key: none
type: none
reflector: none
t: none

set 'qobom func [
	"Simple query dialect for filtering messages"
	data
	dialect
	/local
		selector
		keep-type count-by?
		t
][
	t: now/time/precise
	data-block: data
	clear conditions 
	value: result: none
	group: copy []

	parse dialect main-rule
	time: now/time/precise - t
	result
]
; -- end of context
]
