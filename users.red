#!/usr/local/bin/red
Red [
	Note: "need enbase64url from http-tools"
]

users-file: %/var/www/data/users.red
tokens-file: %/var/www/data/tokens.red

users: none
tokens: none

; -- user management --------------------------------------------------------

load-users: func [][
	users: either any [
		not exists? users-file
		zero? size? users-file
	][
		copy #()
	][
		load users-file
	]
]

save-users: func [][
	save users-file users
]

make-user: func [
	"Returns FALSE when user exists, TOKEN when not and is created"
	name [string!]
	password [string!]
	/local user
][
	if select users name [return false]
	user: compose [
		name: none
		password: none
		salt: none
		version: 1
		created: now/precise
	]
	user/name: name
	user/salt: checksum form now/time/precise 'SHA256
	user/password: checksum rejoin [user/salt password] 'SHA256
	users/:name: user
	save-users
	make-token name
]

login-user: func [
	"Return NONE when user not exists, FALSE when password is wrong or TOKEN"
	name [string!]
	password [string!]
	/local user
][
	user: select users name
	unless user [return none]
	password: checksum rejoin [user/salt password] 'SHA256
	unless equal? password user/password [return false]
	make-token name
]

; -- token management -------------------------------------------------------

load-tokens: func [][
	tokens: either any [
		not exists? tokens-file
		zero? size? tokens-file
	][
		copy #()
	][	
		load tokens-file
	]
	check-tokens
]

save-tokens: func [][
	save tokens-file tokens
]

check-tokens: func [][
	foreach [token data] tokens [
		if data/expires < now/precise [
			remove/key tokens token
			save-tokens
		]
	]
]

make-token: func [name /refresh data /local token][
	data: any [
		data
		enbase64url checksum form now/precise 'sha256
	]
	token: compose [
		name: none
		value: (data)
		expires: (now/precise + 01:00:00) ; TODO: move expiration to settings
	]
	token/name: name
	tokens/:name: token
	save-tokens
	make map! token
]

match-token: func [value][
	foreach [user token] tokens [
		if equal? value token/value [
			make-token/refresh user value
			return user
		]
	]
	return false
]

; -- initalization

load-users
load-tokens
