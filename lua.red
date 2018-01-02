Red []

parse-lua: func [
    data
][
    parse/case data rules/main-rule
]

rules: context [
    ws: charset " ^-^/"
    chars: charset [#"a" - #"z" #"A" - #"Z"]
    digits: charset [#"0" - #"9"]
    chars+under: union chars charset [#"_"]
    chars+digits: union chars+under digits
    hexa-digits:  union union digits charset [#"a" - #"f"] charset [#"A" - #"F"]

    identifier: [chars+under any chars+digits] ;  TODO: underscore + uppercase should not work

    keyword: [
        "and" | "break" | "do" | "else" | "elseif"
    |   "end" | "false" | "for" | "function" | "if"
    |   "in" | "local" | "nil" | "not" | "or"
    |   "repeat" | "return" | "then" | "true" | "until"
    |   "while"
    ]

    token: [
        #"+" | #"-" | #"*" | #"/" | #"%" | #"^^" | #"#"
    |   "==" | "~=" | "<=" | ">=" | #"<" | #">" | #"="
    |   #"(" | #")" | #"{" | #"}" | #"[" | #"]"
    |   #";" | #":" | #"," | 1 3 #"."
    ]

    number: [
        opt #"-"
        some digits
        opt [
            dot
            some digits
        ]
        opt [
            [#"e" | #"E"]
            opt #"-"
            some digits
        ]
    ]

    hexa-number: ["0x" some hexa-digits]

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
        |   number
        |   hexa-number
        ]
    ]
]