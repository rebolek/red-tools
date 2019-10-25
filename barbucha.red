Red[
	Title: "Barbucha - collection of tools for fuzzy testing"
	Author: "Boleslav Březovsky"
]


comment {
	Dialect specs:

		opt [integer!]			;	repeat following type X times
		opt RANDOM				;	return random value
		<datatype>	[word!]		;	value type
		opt <options>			;

	Supported options:

		integer!:
			NEGATIVE			;	return negative integer

		string!:
			LENGTH integer!		;	set string length
		

}

type-templates: [
	datatype! [
		reduce [
			datatype! 
			first random collect [
				foreach word words-of system/words [
					if datatype? get/any word [keep word]
				]
			]
		]
	]
	unset!      [[<TODO>] [<TODO>]]
	none!       [none]
	logic!      [[true] [first random [true false]]]
	block!      [[[foo #bar "baz"]] [collect [loop length [keep random-string length]]]]
	paren!      [[quote (foo #bar "baz")] [<TODO:paren! random>]]
	string!     [["foo"] [random-string length]]
	file!       [[%foo.bar]]
	url!        [[http://foo.bar]]
	char!       [[#"x"] [random 1FFFFFh]]
	integer!    [[0] [random 2147483647]] ; TODO: also negative integers and switch in dialect for it
	float!      [[0.0] [random 1.797693134862315e308]]
	word!       [['foo] [to word! random-string length]]
	set-word!   [[quote foo:] [to set-word! random-string length]]
	lit-word!   [[quote 'foo] [to lit-word! random-string length]]
	get-word!   [[quote :foo] [to get-word! random-string length]]
	refinement! [[/foo] [to refinement! random-string length]]
	issue!      [[#foo] [to issue! random-string length]]
	native!     [<TODO:native!>]
	action!     [<TODO:action!>]
	op!         [<TODO:op!>]
	function!   [<TODO:function!>]
	path!       [[quote foo/bar/baz]]
	lit-path!   [[quote 'foo/bar/baz]]
	set-path!   [[quote foo/bar/baz:]]
	get-path!   [quote :foo/bar/baz]
	routine!    [<TODO:routine!>]
	bitset!     [[charset "bar"] [charset random-string length]]
	point!      [<TODO:point!>]
	object!     [<TODO:object!>]
	typeset!    [<TODO:typeset!>]
	error!      [<TODO:error!>]
	vector!     [[make vector! [integer! 8 10]]]
	hash!       [[make hash! [foo bar baz]]]
	pair!       [[0x0] [random 2147483647x2147483647]]
	percent!    [[0%] [random 1.797693134862315e308%]]
	tuple!      [[0.0.0] [random 255.255.255]] ; TODO: support different length
	map!        [[#(foo: bar)]]
	binary!     [[#{deadcafe}]]
	time!       [[11:22:33]]
	tag!        [[<foo>]]
	email!      [[foo@bar.baz]]
	handle!     [<TODO:handle!>]
	date!       [[27-2-2011]]
]

random-string: func [
	"Return random string"
	length
	; TODO: support description dialect
][
	unless length [length: 8]
	collect/into [loop length [keep #"`" + random 26]] copy {}
]

random-map: func [
	"Return random map"
	size
	/depth
		level
	/local
		make-map map maps out key
][
;  currently creates random map with words as keys and strings as values.
	make-map: func [size][
		to map! make-type collect [
			loop size [
				keep compose [
					random word!
					random string! length (random 1000)
				]
			]
		]
	]
	either level [
		maps: collect [
			loop level [
				keep make-map size
			]
		]
		map: out: take maps
		until [
			key: to word! random-string 8
			map/:key: take maps
			map: map/:key
			empty? maps
		]
		out
	][
		make-map size
	]
]

context [
	action: none
	length: 8

	rules: [
		float! integer! pair! percent! [['negative (action: [negate value])]]
		string! word! set-word! get-word! lit-word! [[
			'length set value integer! (pre-action: compose [length: (value)])
		]]
	]


	set 'make-type func [
		"Return default value of given type"
		type	[datatype! block!] "Type of value or dialect specs"
		/random	"Return random value of given type"
		/local
			species values results
			repetition
	][
		if datatype? type [type: reduce [type]]
		species: 1 ; 1 - default, 2 - random
		length: 8  ; default length for random strings
		repetition: 1
		values: copy []	; internal "dialect": [type random? options]
		results: copy []

		parse type [
			some [
				(species: repetition: 1)
				(pre-action: action: none)
				(length: 8)
				opt [set repetition integer!]
				opt ['random (species: 2)] 
				set type skip
				(opt-rule: switch to word! type rules)
				opt opt-rule
				(
					loop repetition [
						repend values [to word! type species pre-action action]
					]
				)
			]
		]

		foreach [type species pre-act act] values [
		; NOTE: This is bit crazy, but when binding length directly,
		;		code not using length somehow stops working
			length: 8
			do pre-act
			value: select type-templates type
			value: any [pick value species first value]
			value: func [length] value
			value: value length
			if action [value: do action]
			append/only results value
		]
		results
	]
]
