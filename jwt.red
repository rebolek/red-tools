Red[
	Notes: [
		RFC7519 JWT
		RFC4648 base64url
	]
]

header: {{"alg":"HS256","typ":"JWT"}}

payload: {{"sub":"1234567890","name":"John Doe","iat":1516239022}}

strip: func [value [string!] /local equal ][
	either equal: find value #"=" [head clear equal][value]
]

enbase64url: func [value [string! binary!]][
	value: enbase/base value 64
	if mark: find value #"=" [value: head clear mark]
	replace/all value #"/" #"_"
	replace/all value #"+" #"-"
	value
]

encode: func [
	header
	payload
	secret
][
	unless string? header [header: to-json header]
	unless string? payload [payload: to-json payload]
	data: rejoin [enbase64url header dot enbase64url payload]
	signature: checksum/with data 'SHA256 secret
	rejoin [data dot enbase64url signature]
]
