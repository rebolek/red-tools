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


ufcs: func [
    series
    dialect
    /local result action args code
][
    result: none
    code: []
    until [
        clear code
        insert code action: take dialect
        append/only code series
        args: (arity get action) - 1
        unless zero? args [append code take dialect]
        do code
        empty? dialect
    ]
    series
]