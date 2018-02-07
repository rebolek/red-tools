Red[
    Title: "UFCS dialect"
    Author: "Boleslav Březovský"
    Purpose: "Provide kind of Unified Fuction Call Syntax for Red"
    Todo: "Add refinements support"
]

actions: does [
    collect [
        foreach word words-of system/words [
            if action? get/any word [keep word]
        ]
    ]
]

arity: func [
    "Return function's arity (ignores refinements for now)"
    fn
][
    count: 0
    parse spec-of :fn [
        some [
            word! (count: count + 1)
        |   string! | block!
        |   refinement! to end
        |   skip    
        ]
    ]
    count
]

arity?: func [
    "Return function's arity" ; TODO: support for lit-word! and get-word! ?
    fn
    /local count name refinement-rule
][
    result: copy []
    count: 0
    name: none
    count-rule: [
        some [
            word! (count: count + 1)
        |   ahead refinement! refinement-rule
        |   skip
        ]
    ] 
    refinement-rule: [
        (repend result either name [[name count]][[count]])
        set name refinement!
        (count: 0)
        count-rule
    ]
    parse spec-of :fn count-rule
    repend result either name [[name count]][[count]]
    result
]

refinements?: func [
    "Return block of refinements for given function"
    fn
    /local value
][
    parse spec-of :fn [
        collect [some [set value refinement! keep (to word! value) | skip]]
    ]
]

ufcs: func [
    series
    dialect
    /local result action args code
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
        do code
        empty? dialect
    ]
    series
]