Red[
    Title: "Various function! related tools"
    Author: "Boleslav Březovský"
    Note: {
For details about these functions, see my articles:

`apply`, `ufc` - http://red.qyz.cz/apply-and-ufcs.html
`dispatcher`   - http://red.qyz.cz/pattern-matching.html
}
]

actions: has [
    "Return block of all actions"
    result
][
    result: []
    if empty? result [
        result: collect [
            foreach word words-of system/words [
                if action? get/any word [keep word]
            ]
        ]
    ]
    result
]

op: func [
    "Defines op! with given spec and body"
    spec [block!]
    body [block!]
][
    make op! func spec body
]

; --- get arity and refinements ------------------------------------------------

arity?: func [
    "Return function's arity" ; TODO: support for lit-word! and get-word! ?
    fn [any-function!]  "Function to examine"
    /local result count name count-rule refinement-rule append-name
][
    result: copy []
    count: 0
    name: none
    append-name: quote (repend result either name [[name count]][[count]]) 
    count-rule: [
        some [
            word! (count: count + 1)
        |   ahead refinement! refinement-rule
        |   skip
        ]
    ] 
    refinement-rule: [
        append-name
        set name refinement!
        (count: 0)
        count-rule
    ]
    parse spec-of :fn count-rule
    do append-name
    either find result /local [
        head remove/part find result /local 2
    ][result]
]

refinements?: func [
    "Return block of refinements for given function"
    fn      [any-function!] "Function to examine"
    /local value
][
    parse spec-of :fn [
        collect [some [set value refinement! keep (to word! value) | skip]]
    ]
]

; --- unified function call syntax ---------------------------------------------

ufcs: func [
    "Apply functions to given series"
    series  [series!]       "Series to manipulate"
    dialect [block!]        "Block of actions and arguments, without first argument (series defined above)"
    /local result action args code arity refs ref-stack refs?
][
    result: none
    code: []
    until [
        ; do some preparation
        clear code
        action: take dialect
        arity: arity? get action
        args: arity/1 - 1
        refs: refinements? get action
        ref-stack: clear []
        refs?: false
        unless zero? args [append ref-stack take dialect]
        ; check for refinements
        while [find refs first dialect][
            refs?: true
            ref: take dialect
            either path? action [
                append action ref 
            ][
                action: make path! reduce [action ref]
            ] 
            unless zero? select arity ref [
                append ref-stack take dialect 
            ]
        ]
        ; put all code together
        append/only code action 
        append/only code series
        unless empty? ref-stack [append code ref-stack]
        series: do code
        empty? dialect
    ]
    series
]

ufc: function [
    "Apply functions to given series"
    data    [series!] "Series to manipulate"
    dialect [block!]  "Block of actions and arguments, without first argument (series defined above)"
][
    foreach [cmd args] dialect [
        data: apply get cmd head insert/only args data
    ]
    data
]

; --- apply function -----------------------------------------------------------

apply: func [
    "Apply a function to a block of arguments"
    fn      [any-function!] "Function value to apply"
    args    [block!]        "Block of arguments (to quote refinement use QUOTE keyword)"
    /local refs vals val
][
    refs: copy []
    vals: copy []
    set-val: [set val skip (append/only vals val)]
    parse args [
        some [
            'quote set-val
        |   set val refinement! (append refs to word! val)
        |   set-val
        ]
    ]
    do compose [(make path! head insert refs 'fn) (vals)]
]

map: func [
	"Apply code over block of values"
	data
	code
	/local f
][
	data: copy data
	f: get take code
	forall data [
		data/1: apply :f compose [(first data) (code)]
	]
	data
]

map-each: func [
    'word
    series
    code
][
    collect [
        until [
            set :word first series
            keep do code
            series: next series
            tail? series
        ]
    ]
]

; --- make default value of given type -----------------------------------------

comment {
	Dialect specs:

		opt [integer!]			;	repeat following type X times
		opt RANDOM				;	return random value
		<datatype>	[word!]		;	value type
		opt <options>			;

	Supported options:

		integer!				;	set string length

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
	block!      [[[foo #bar "baz"]] [<TODO>]]
	paren!      [[quote (foo #bar "baz")] [<TODO>]]
	string!     [["foo"] [random-string length]]
	file!       [[%foo.bar]]
	url!        [[http://foo.bar]]
	char!       [[#"x"] [random 1FFFFFh]]
	integer!    [[0] [random 2147483647]] ; TODO: also negative integers and switch in dialect for it
	float!      [[0.0] [random 1.797693134862315e308]]
	word!       [['foo]]
	set-word!   [[quote foo:] [to set-word! random-string length]]
	lit-word!   [[quote 'foo] [to lit-word! random-string length]]
	get-word!   [[quote :foo] [to get-word! random-string length]]
	refinement! [[/foo] [to refinement! random-string length]]
	issue!      [[#foo] [to issue! random-string length]]
	native!     [<TODO>]
	action!     [<TODO>]
	op!         [<TODO>]
	function!   [<TODO>]
	path!       [[quote foo/bar/baz]]
	lit-path!   [[quote 'foo/bar/baz]]
	set-path!   [[quote foo/bar/baz:]]
	get-path!   [quote :foo/bar/baz]
	routine!    [<TODO>]
	bitset!     [[charset "bar"] [charset random-string length]]
	point!      [<TODO>]
	object!     [<TODO>]
	typeset!    [<TODO>]
	error!      [<TODO>]
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
	handle!     [<TODO>]
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

make-type: func [
	"Return default value of given type"
	type	[datatype! block!] "Type of value or dialect specs"
	/random	"Return random value of given type"
	/local
		species length values results
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
			opt [set repetition integer!]
			'random (species: 2) set type skip
			(loop repetition [repend values [to word! type species none]])
		]
	]

	foreach [type species opts] values [
		t: select type-templates type
		t: any [pick t species first t]
		t: bind t 'length
		append results do bind t 'length
	]
	results
]

; --- dispatch function --------------------------------------------------------

dispatcher: func [
	"Return dispatcher function that can be extended with DISPATCH"
	spec [block!] "Function specification"
][
	func spec [
		case []
	]
]

dispatch: func [
	"Add new condition and action to DISPATCHER function"
	dispatcher  [any-function!] "Dispatcher function to use"
	cond		[block! none!]	"Block of conditions to pass or NONE for catch-all condition (forces /RELAX)" 
	body		[block! none!]  "Action to do when condition is fulfilled or NONE for removing rule"
	/relax						"Add condition to end of rules instead of beginning"
	/local this cases mark penultimo
][
	cases: second body-of :dispatcher
    penultimo: back back tail cases
    unless equal? true first penultimo [penultimo: tail cases]
    if cond [bind cond :dispatcher]
    if body [bind body :dispatcher]
	this: compose/deep [all [(cond)] [(body)]]
	case [
        all [not cond not body not empty? penultimo][remove/part penultimo 2]   ; remove catch-all rule (if exists)
        all [not body mark: find/only cases cond][remove/part back mark 3]      ; remove rule (if exists)
        all [not cond true = first penultimo][change/only next penultimo body]  ; change catch-all rule (if exists)
        not cond                            [repend cases [true body]]          ; add catch-all rule
		mark: find/only cases cond 	        [change/part back mark this 3]      ; change existing rule (if exists)
		relax 				    	        [insert penultimo this]             ; add new rule to end
		'default 				            [insert cases this]                 ; add new rule to beginning
	]
	:dispatcher
]

; --- function constructors --------------------------------------------

dfunc: func [
    "Define function with default values for local words"
    spec
    body
][
    ; format for default values is [set-word: value] after /local refinement
    ; it's possible to mix normal words (without default value) and set-words
    local: copy []
    locals: copy #()
    if mark: find spec /local [
        parse next mark [
            some [
                set word set-word!
                set value skip (
                    append local to word! word
                    locals/:word: value
                )
            |   set word word! (append local word)
            ]
        ]
        remove/part mark length? mark
        append spec compose [/local (local)]
        foreach word words-of locals [
            insert body reduce [to set-word! word locals/:word]
        ]
    ]
    func spec body
]
