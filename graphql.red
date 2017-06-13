Red [
	Title: "GraphQL"
	Author: "Boleslav Březovský"
	Link: https://facebook.github.io/graphql/
]


; === GraphQL parser =========================================================
;
; check GraphQL validity

; source text

source-char: charset reduce [tab cr lf #" " '- #"^(FFFF)"]
unicode-bom: #"^(FEFF)"
whitespace: charset reduce [space tab]
ws: [any ignored]
line-terminator: charset reduce [cr lf] ; [crlf | cr | lf]
comment: [#"#" ws some comment-char ws]
comment-char: difference source-char line-terminator
; comma - already defined in Red
token: [punctuator | name | int-value | float-value | string-value]
ignored: [unicode-bom | whitespace | line-terminator | comment | comma]
punctuator-chars: charset "!$():=@[]{|}"
punctuator: [punctuator-chars | "..."]
name: [start-name-char some name-char]
start-name-char: charset [#"_" #"A" - #"Z" #"a" - #"z"] 
name-char: union start-name-char charset [#"0" - #"9"]

; query document

; TODO: add whitespaces

document: [some definition]
definition: [
	operation-definition 
|	fragment-definition
]
operation-definition: [
	ws operation-type ws opt name opt variable-definitions opt directives selection-set
|	selection-set
]
operation-type: ["query" | "mutation" | "subscription"]
selection-set: [ws #"{" ws some selection ws #"}" ws]
selection: [
	ws field ws
|	ws fragment-spread ws
|	ws inline-fragment ws
]
field: [
	opt [alias ws]
	name ws
	opt [arguments ws]
	opt [directives ws]
	opt selection-set
]
arguments: [#"(" ws argument ws any [ws argument ws] ws #")" ws]
argument: [name #":" ws value ws]
alias: [name #":"]
fragment-spread: ["..." ws fragment-name ws opt directives] ; starts with ..., wtf is it
fragment-definition: [
	"fragment" ws
	fragment-name ws
	type-condition ws
	opt directives ws
	selection-set
]
fragment-name: [ahead not "on" name]
type-condition: ["on" ws named-type]
inline-fragment: [
	"..." ws
	opt type-condition
	opt directives
	selection-set
]
value: [ ; wtf is const and ~const ?
	variable
|	int-value
|	float-value
|	string-value
|	boolean-value
|	null-value
|	enum-value
|	list-value
|	object-value
]
int-value: [integer-part]
integer-part: [
	opt negative-sign #"0"
|	opt negative-sign non-zero-digit any digit
]
negative-sign: #"-"
digit: charset [#"0" - #"9"]
non-zero-digit: difference digit charset #"0"
float-value: [
	integer-part fractional-part exponent-part
|	integer-part fractional-part
|	integer-part exponent-part
]
fractional-part: [#"." some digit]
exponent-part: [exponent-indicator opt sign some digit]
exponent-indicator: charset "eE"
sign: charset "+-"
boolean-value: ["true" | "false"]
string-value: [{""} | #"^"" some string-char #"^""]
string-char: [
	ahead not [#"^"" | #"\" | line-terminator] source-char
|	{\u} escaped-unicode
|	#"\" escaped-char
]
hex-char: charset [#"0" - #"9" #"a" - #"f" #"A" - #"F"]
escaped-unicode: [4 hex-char]
escaped-char: charset "^"\/bfnrt"
null-value: "null"
enum-value: [ahead not ["true" | "false" | "null"] name]
list-value: [
	"[]"
|	#"[" ws value any [ws value] ws #"]"	
]
object-value: [
	"{}"
|	ws #"{" ws object-field ws #"}" ws
]
object-field: [ws name #":" ws value any [ws name #":" ws value] ws]
variable: [#"$" name]
variable-definitions: [#"(" ws some variable-definition ws #")"]
variable-definition: [variable #":" ws type opt default-value ws]
default-value: [ws #"=" ws value ws]
type: [named-type | list-type | non-null-type]
named-type: [name]
list-type: [#"[" ws type ws #"]"]
non-null-type: [
	named-type #"!"
|	list-type #"!"
]
directives: [some directive]
directive: [#"@" name ws opt arguments]




tests: [
; ---[1]	
	{
mutation {
  likeStory(storyID: 12345) {
	story {
	  likeCount
	}
  }
}		
	}
; ---[2]
	{
{
  me {
	id
	firstName
	lastName
	birthday {
	  month
	  day
	}
	friends {
	  name
	}
  }
}		
	}
; ---[3]
	{
# `me` could represent the currently logged in viewer.
{
  me {
	name
  }
}
	}
; ---[4]
	{
# `user` represents one of many users in a graph of data, referred to by a
# unique identifier.
{
  user(id: 4) {
	name
  }
}
	}
; ---[5]
	{
{
  user(id: 4) {
	id
	name
	profilePic(size: 100)
  }
}		
	}
; ---[6]
	{
{
  user(id: 4) {
	id
	name
	profilePic(width: 100, height: 50)
  }
}
	}
; ---[7]
	{
{
  user(id: 4) {
	id
	name
	smallPic: profilePic(size: 64)
	bigPic: profilePic(size: 1024)
  }
}
	}
; ---[8]
	{
query noFragments {
  user(id: 4) {
	friends(first: 10) {
	  id
	  name
	  profilePic(size: 50)
	}
	mutualFriends(first: 10) {
	  id
	  name
	  profilePic(size: 50)
	}
  }
}
	}
; ---[9]
	{
query withFragments {
  user(id: 4) {
	friends(first: 10) {
	  ...friendFields
	}
	mutualFriends(first: 10) {
	  ...friendFields
	}
  }
}

fragment friendFields on User {
  id
  name
  profilePic(size: 50)
}
	}
; ---[10]
	{
query withNestedFragments {
  user(id: 4) {
	friends(first: 10) {
	  ...friendFields
	}
	mutualFriends(first: 10) {
	  ...friendFields
	}
  }
}

fragment friendFields on User {
  id
  name
  ...standardProfilePic
}

fragment standardProfilePic on User {
  profilePic(size: 50)
}
	}
; ---[11]
	{
query FragmentTyping {
  profiles(handles: ["zuck", "cocacola"]) {
	handle
	...userFragment
	...pageFragment
  }
}

fragment userFragment on User {
  friends {
	count
  }
}

fragment pageFragment on Page {
  likers {
	count
  }
}
	}
; ---[12]
	{
query inlineFragmentTyping {
  profiles(handles: ["zuck", "cocacola"]) {
	handle
	... on User {
	  friends {
		count
	  }
	}
	... on Page {
	  likers {
		count
	  }
	}
  }
}
	}
; ---[13]
	{
query inlineFragmentNoType($expandedInfo: Boolean) {
  user(handle: "zuck") {
	id
	name
	... @include(if: $expandedInfo) {
	  firstName
	  lastName
	  birthday
	}
  }
}
	}
; ---[14] 
	{
{
  entity {
    name
    ... on Person {
      age
    }
  },
  phoneNumber
}
	}
]