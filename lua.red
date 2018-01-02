Red []

parse-lua: func [
    data
][
    parse data rules/main-rule
]

rules: context [
    ws: charset " ^-^/"
    chars: charset [#"a" - #"z" #"A" - #"Z"]
    digits: charse [#"0" - #"9"]
    chars+under: union chars charset [#"_"]
    chars+digits: union chars+under digits

    identifier: [chars+under any chars+digits] ;  TODO: underscore + uppercase should not work

    keyword: [
        'and | 'break | 'do | 'else | 'elseif
    |    'end | 'false | 'for | 'function | 'if
    |    'in | 'local | 'nil | 'not | 'or
    |    'repeat | 'return | 'then | 'true | 'until
    |    'while
    ]

    comment: [
        single-line-comment
    |   multi-line-comment    
    ]
    single-line-comment: [
        any ws "--" thru [newline | end]
    ]
    multi-line-comment: [
        any ws "--[[" thru "]]"
    ]

    main-rule: [
        some [
            comment
        ]
    ]
]