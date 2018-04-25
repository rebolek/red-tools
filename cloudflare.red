Red[
    Title: "CLoudflare API"
    Author: "Boleslav Březovský"
    Url: https://api.cloudflare.com

    Usage: [
        do %cloudflare.red
        opt: load %cloudflare-options.red
        cf: make cloudflare! opt
    ]
]

base-url: https://api.cloudflare.com/client/v4/

do %json.red
do %http-tools.red

cloudflare!: context [
    ; user settings
    api-key: none
    email: none

    ; support
    reply: none ; reply from server
    zone-cache: none

    ; main function
    send: func [
        link
        /local method header
    ][
        link: rejoin [base-url link]
        method: 'GET
        header: make map! compose [
            X-Auth-Key: (form self/api-key)
            X-Auth-Email: (form self/email)
            ; TODO: X-Auth-User-Service-Key
        ]
        self/reply: send-request/with link method header
        ; TODO: error handling
        self/reply/data
    ]

    ; --- support functions

    id?: func [
        "Return TRUE when string is ID"
        string
        /local hexa
    ][
        hexa: charset [#"a" - #"f" #"0" - #"9"]
        parse string [32 hexa]
    ]

    get-zone-id: func [
        name
    ][
        foreach zone self/zone-cache [
            if equal? name zone/name [return zone/id]
        ]
        none
    ]

    ; --- API implementation

    get-zones: func [][
        ; TODO: Pagination
        self/send %zones
        self/zone-cache: copy self/reply/data/result
    ]

    list-dns-records: func [
        zone
    ][
        unless id? zone [
            if empty? self/zone-cache [get-zones]
            zone: self/get-zone-id zone
        ]
        self/send rejoin [%zones/ zone "/dns_records"]
        self/reply/data/result
    ]

    make-dns-record: func [
        type 
        name 
        content
        ; TODO: optional args
    ][
;        self/send
    ]
]


test: [
    opt: load %cloudflare-options.red
    cf: make cloudflare! opt
    cf/get-zones
]