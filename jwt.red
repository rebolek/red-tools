Red[
	Resources: [
		https://jwt.io/
		JWT: RFC7519 https://tools.ietf.org/html/rfc7519
		base64url: RFC4648 https://tools.ietf.org/html/rfc4648
	]
]

header: {{"alg":"HS256","typ":"JWT"}}

payload: {{"sub":"1234567890","name":"John Doe","iat":1516239022}}


jwt: context [

	header-proto: #(alg: 'HS256 typ: 'JWT)

	registered-claims: [
		iss "Issuer" [string! url!]
		sub "Subject" [string! url!]
		aud "Audience" [string! url!]
		exp "Expiration Time" [integer!]
		nbf "Not Before" [integer!]
		iat "Issued At" [integer!]
		jto "JWT ID" [string!]
	]

	jose-header: [
		typ "Type" [string!]
		cty "Content Type" ["JWT"]
	]

	enbase64url: func [value [string! binary!]][
		value: enbase/base value 64
		if mark: find value #"=" [value: head clear mark]
		replace/all value #"/" #"_"
		replace/all value #"+" #"-"
		value
	]

	debase64url: func [value /json][
		; TODO: Add = when missing
		value: to string! debase value
		if json [value: load-json value]
		value
	]

	set 'to-jwt func [
		header [map! none!]
		payload [map!]
		secret [string! binary!]
	][
		unless header [header: header-proto]
		unless string? header [header: to-json header]
		unless string? payload [payload: to-json payload]
		data: rejoin [enbase64url header dot enbase64url payload]
		signature: checksum/with data 'SHA256 secret
		rejoin [data dot enbase64url signature]
	]

	set 'load-jwt func [
		value [string!]
	][
		value: split value dot
		header: debase64url/json value/1
		payload: debase64url/json value/1
	]

]
