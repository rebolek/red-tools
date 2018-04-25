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
        /with method data
        /local header
    ][
        link: rejoin [base-url link]
        method: any [method 'GET]
        header: make map! compose [
            X-Auth-Key: (form self/api-key)
            X-Auth-Email: (form self/email)
            ; TODO: X-Auth-User-Service-Key
        ]
        self/reply: either equal? method 'get [
            send-request/with link method header
        ] [
            header/Content-Type: "application/json"
            send-request/with/data link method header data
        ]
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
        either self/id? name [
            name
        ][
            if empty? self/zone-cache [self/get-zones]
            foreach zone self/zone-cache [
                if equal? name zone/name [return zone/id]
            ]
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
        zone: self/get-zone-id zone
        self/send rejoin [%zones/ zone "/dns_records"]
        self/reply/data/result
    ]

    make-dns-record: func [
        zone
        type 
        name 
        content
        ; TODO: optional args
    ][
        zone: self/get-zone-id zone
        self/send/with rejoin [%zones/ zone "/dns_records"] 'POST json/encode make map! compose [
            type: (type)
            name: (name)
            content: (content)
        ] 
    ]
]


test: [
    opt: load %cloudflare-options.red
    cf: make cloudflare! opt
    cf/get-zones
]