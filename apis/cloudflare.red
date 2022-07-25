Red[
	Title: "Cloudflare API"
	Author: "Boleslav Březovský"
	Url: https://api.cloudflare.com
	
	Options: [
		api-key: "your-api-key-here"
		email: your@email.here	
	]

	Usage: [
		do %cloudflare.red
		opt: load %cloudflare-options.red
		cf: make cloudflare! opt
	]
]

base-url: https://api.cloudflare.com/client/v4/

do %../http-tools.red

cloudflare!: context [
	; user settings
	token: none
	email: none

	; support
	reply: none ; reply from server
	zone-cache: none
	dns-cache: #()

	; main function
	send: func [
		link
		/with method data
		/local header
	][
		link: rejoin [base-url link]
		method: any [method 'GET]
		header: make map! compose [
			Content-Type: "application/json"
		]
		reply: either equal? method 'get [
			send-request/with/auth link method header 'Bearer token
		] [
			send-request/with/data/auth link method header data 'Bearer token
		]
		; TODO: error handling
		either reply/code = 200 [
			reply/data
		][
			make error! rejoin [
				reply/data/errors/1/code ": " reply/data/errors/1/message
			]
		]
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
		either id? name [
			return name
		][
			if empty? zone-cache [get-zones]
			foreach zone zone-cache [
				if equal? name zone/name [return zone/id]
			]
		]
		none
	]

	get-zone-name: func [zone-id][
		foreach zone zone-cache [
			if equal? zone-id zone/id [return zone/name]
		]
	]

	get-dns-record-id: func [
		zone
		name
		/local zone-name records
	][
		; prepare caches
		zone: get-zone-id zone
		zone-name: get-zone-name zone
		if empty? words-of dns-cache [list-dns-records zone]
		;  make sure that name contains zone name
		unless find name zone-name [name: rejoin [name dot zone-name]]
		; find record ID
		records: select dns-cache zone
		foreach record records [
			if equal? name record/name [return record/id]
		]
		none
	]

	; --- API implementation

	verify: func [] [
		send %user/tokens/verify
		copy reply/data/result
	]

	get-zones: func [][
		; TODO: Pagination
		send %zones
		zone-cache: copy reply/data/result
	]

	list-dns-records: func [
		zone
	][
		zone: get-zone-id zone
		send rejoin [%zones/ zone "/dns_records"]
		dns-cache/:zone: reply/data/result
	]

	make-dns-record: func [
		zone
		type
		name
		content
		; TODO: optional args
	][
		zone: get-zone-id zone
		send/with rejoin [%zones/ zone "/dns_records"] 'POST json/encode make map! compose [
			type: (type)
			name: (name)
			content: (content)
		]
	]

	update-dns-record: func [
		zone
		type
		name
		content
		; TODO: optional args
		/local id
	][
		id: get-dns-record-id zone name
		zone: get-zone-id zone
		send/with rejoin [%zones/ zone "/dns_records/" :id] 'PUT json/encode make map! compose [
			type: (type)
			name: (name)
			content: (content)
		]
	]

	delete-dns-record: func [
		zone
		name
	][
;		DELETE zones/:zone_identifier/dns_records/:identifier
		id: get-dns-record-id zone name
		zone: get-zone-id zone
		send/with rejoin [%zones/ zone "/dns_records/" :id] 'DELETE []
	]
]

test: [
	opt: load %cloudflare-options.red
	cf: make cloudflare! opt
	cf/get-zones
]
