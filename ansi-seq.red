Red [
    To-Do: "Write dialect that will be converted to `print-seq` format"
]

ansi: context [

esc-main: #{1B5B} ; ESC+[
clear-screen: append copy esc-main "2J"

print-esc: func [data][foreach char data [prin to char! char]]
print-seq: func [
    "Print combination of text and ANSI sequences"
    data [block!] "Block of binary! and string! values"
][
    foreach value data [
        switch type?/word value [
            string! [prin value]
            binary! [print-esc value]
        ]
    ]
]

set-color: func [type color][
    type: either equal? 'fg type [#"3"][#"4"]
    colors: [black red green yellow blue magenta cyan white]
    all [
        color: find colors color
        color: index? color
        rejoin [esc-main type 47 + color #"m"]
    ]
]

set-position: func [position][
    rejoin [esc-main form position/x #";" form position/y #"H"]
]

demo: does [
    do [cls at 1x1 fg red "Welcome to " fg green bg white "ANSI" reset bold " console" reset]
]

do: func [data][
    print-seq parse data [
        collect [
            some [
                'reset keep (rejoin [esc-main "0m"])
            |   'cls keep (clear-screen)
            |   'bold keep (rejoin [esc-main "1m"])
            |   'italic keep (rejoin [esc-main "3m"])
            |   'underline keep (rejoin [esc-main "4m"])
            |   'at set value pair! keep (probe set-position value)
            |    set type ['fg | 'bg] set value word! keep (set-color type value)
            |   keep string! 
            ]
        ]
    ]
]

; -- end of context
]