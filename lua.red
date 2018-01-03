Red [
    Title: "Lua parser"
    Specs: http://www.lua.org/manual/5.1/manual.html
]

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
    name: [identifier]
    namelist: [name any [any ws comma any ws name]]
    var: [name]
    varlist: [var any [any ws comma any ws var]] ; TODO: capture vals


    float-number: [
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
    number: [float-number | hexa-number]

    exp: [ ; expression
        prefix-exp
    |   "nil" | "false"  | "true"
    |   number
    |   string
;    |   function
;    |   table-constructor
    |   "..."
;    |   exp bin-op exp
;    |   un-op exp    
    ]
    prefix-exp: [
        var
;    |   function-call
;    |   #"(" exp #")" 
    ]
    explist: [exp any [any ws comma any ws exp]]

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

    chunk: [some [stat opt #";"]]

    block: [chunk]

    stat: [
        "do" some ws block some ws "end"
    |   control-structures
    |   "return" opt explist
    |   "break"
    |   for-stat
    |   varlist any ws #"=" any ws explist
    ]

    control-structures: [
        while-struc
    |   repeat-struc
    |   if-struc  
;    |   function-call  
    ]
    struc-exp: [some ws exp some ws]
    struc-act: [some ws block some ws]
    while-struc: [
        "while" struc-exp
        "do" struc-act "end"
    ]
    repeat-struc: [
        "repeat" struc-act
        "until" struc-exp
        "end"
    ]
    if-struc: [
        "if" struc-exp "then" struc-act
        any ["elseif" struc-exp "then" struc-act]
        opt ["else" struc-act]
        "end"
    ]

    iterator: ""
    for-stat: [for-numeric | for-generic]
    for-numeric: [
        "for" some ws copy iterator name some ws
        #"=" some ws
        exp any ws #"," any ws exp opt [any ws #"," any ws exp]
        some ws "do" some ws
        block some ws
        "end"
    ]
    for-generic: [
        "for" some ws namelist some ws
        "in" some ws explist some ws
        "do" some ws
        block some ws
        "end"
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

    ; strings-todo: add escape sequences
    quot: none
    literal-string: [
        set quot [#"'" | #"^""]
        copy str any [
            #"\" quot
        |   not quot skip
        ]
        quot
    ]
    level: ""
    end-long-string: [#"]" level #"]"]
    long-string: [
        #"[" copy level any #"=" #"["
        opt newline
        copy str any [
            not end-long-string skip
        ]
        end-long-string
    ]
    string: [
        literal-string
    |   long-string        
    ]

    main-rule: [
        some [
            comment
        |   stat
        |   any ws
        ]
    ]
]