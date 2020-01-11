Red[
	Title: "SANSCrypt - Simple And Naive Symmetric Crypto"
	Author: "Boleslav Březovský"
	Purpose: "Placeholder symmetric cryptography until Red gets real thing"
]

.: context [

binc: func [
	"Binary increase"
	value [binary!]
][
	len: length? value
	value/:len: value/:len + 1
	repeat i len [
		i: len - i + 1
		either zero? value/:i [
			value/(i - 1): value/(i - 1) + 1
		][
			break
		]
	]
	value
]

make-nonce: func [
	"Return random binary. Default is 256 bits"
	/size
		length	"Size in bits"
][
	length: any [length 256]
	collect/into [
		loop length / 8 [keep (random 256) - 1]
	] copy #{}
]

crypt: func [
	value		[string! binary!]
	password	[string!]
	nonce		[binary!]
][
	data: copy #{}
	until [
		block: copy/part value 32
		value: skip value 32
		key: checksum rejoin [#{} password form nonce] 'sha256
		block: key xor to binary! block
		append data block
		binc nonce
		tail? value
	]
	data
]

set 'encrypt func [
	value [string! binary!]
	password [string!]
][
	nonce: make-nonce
	orig: copy nonce
	value: crypt value password nonce
	reduce [orig value]
]

set 'decrypt func [
	value		[string! binary!]
	password	[string!]
	nonce		[binary!]
][
	crypt value password nonce
]

; -- end of context
]
