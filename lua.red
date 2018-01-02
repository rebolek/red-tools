Red []

parse-lua: func [
    data
][
    parse data rules/main-rule
]

rules: context [
    ws: charset " ^-^/"
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