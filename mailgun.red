Red[
    Title: "Mailgun API"
    Author: "Boleslav Březovský"
    Usage: {
Make your own `mailgun` object like this:

```
my-mailgun: make mailgun! [
    api:    <your API key>
    domain: <your domain>
    from:   <your email address>
]
```
}
    API: https://documentation.mailgun.com/en/latest
]

;sony@deli:~/Code/temp$ curl -s --user 'api:key-3c3fad7221f6f700b13724fab19cfd0c' \
;>     https://api.mailgun.net/v3/sandbox915666ebdc3a47ddaff441ebff290da1.mailgun.org/messages \
;>         -F from='Mailgun Sandbox <postmaster@sandbox915666ebdc3a47ddaff441ebff290da1.mailgun.org>' \
;>         -F to='Ivan Vrah <rebolek@gmail.com>' \
;>         -F subject='Hello Ivan Vrah' \
;>         -F text='Congratulations Ivan Vrah, you just sent an email with Mailgun!  You are truly awesome!'

do %http-tools.red

mailgun!: context [
    api: none ; put your API key here

    base-url: https://api.mailgun.net/v3/
    domain: none ; put your domain here
    from: none ; put your email address here

    send: func [
        recepients
        subject ; TODO: get subject from body as first line?
        body
        /local ret link method
    ][
        link: rejoin [base-url self/domain /messages]
        method: 'POST
        data: ""
        headers: make map! compose [
            from:       (self/from)
            to:         (recepients)  ; TODO: conversion to comma separated format
            ; TODO: CC, BCC
            subject:    (subject)
            text:       (body)
            ; TODO: Attachment and other headers
        ]
        ret: send-request/auth/data/with link method 'basic reduce ["api" self/api] data headers
        load-json ret
        ; TODO: Error handling
    ]
]
