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
    api-key: none
    email: none

    reply: none ; reply from server

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

    get-zones: func [][
        self/send %zones
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