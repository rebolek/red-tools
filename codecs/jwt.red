Red [
	Title: "JWT -JSON eb Token implementation for Red"
	Author: "Boleslav Březovsk"
	Resources: [
		https://jwt.io/introduction/
		https://tools.ietf.org/html/rfc7519
	]
]

; -- support funcs ----------------------------------------------------------

enbase64: func [
	"Convert data to base64 and strip padding"
	data
	/safe	"Use safe alphabet"
][
	data: enbase/base data 64
	while [equal? #"=" last data][take/last data]
	if safe [ensafe64 data]
	data
]

debase64: func [
	"Debase Base64 data with padding control"
	data
	/safe	"Use safe alphabet"
	/local rem
][
	unless zero? rem: (length? data) // 4 [
		append/dup data #"=" 4 - rem
	]
	if safe [desafe64 data]
	debase/base data 64
]

ensafe64: func [
	"Change base64-encoded string to safe encoding (modifies)"
	data	[string!]
][
	replace/all data #"+" #"-"
	replace/all data #"/" #"_"
	data
]

desafe64: func [
	"Change base64-encoded string form safe encoding (modifies)"
	data	[string!]
][
	replace/all data #"-" #"+"
	replace/all data #"_" #"/"
	data
]

; -- structure info ---------------------------------------------------------

structure: [
	header
	payload
	signature
]

payload-types: [
	registered
	public
	private
]

registered-claims: [
	iss	"Issuer"
	sub	"Subject"
	aud	"Audience"
	exp	"Expiration Time"
	nbf	"Not Before"
	iat	"Issued At"
	jti	"JWT ID"
]

make-header: func [
	/local header
][
	header: make map! [
		alg: "HS256"
		typ: "JWT"
	]
	enbase64 to-json header
]

make-payload: func [
	claim [map! object!]
][
	enbase64 to-json claim
]

sign: func [
	header	[string!]
	payload	[string!]
	secret	[string! binary!]
	/local data
][
	data: rejoin [header dot payload]
	data: checksum/with data 'SHA256 secret
	rejoin [header dot payload dot enbase64/safe data]
]

to-jwt: func [
	data	[map! object!]
	secret	[string! binary!]
][
	sign make-header make-payload data secret
]

load-jwt: func [
	token
	/local result
][
	token: split token dot
	forall token [
		; add padding when necessary
		unless zero? rem: (length? token/1) // 4 [
			append/dup token/1 #"=" 4 - rem
		]
		token/1: debase token/1
	]
	result: to map! compose [
		header (load-json to string! token/1)
		payload (load-json to string! token/2)
		secret
	]
]
