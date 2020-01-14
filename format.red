Red[
	Title: "Formating functions"
	Author: "Boleslav Březovský"
]


context [
tabs: func [
	"Return required number of tabs"
	count [integer!]
][
	append/dup copy {} tab count
]

spaces: func [
	"Return required number of spaces"
	count [integer!]
][
	append/dup copy {} space count
]

set 'entab func [
	"Convert spaces to tabs (modifies)"
	value [string!] "Script to convert"
	/count			"Number of spaces in tab /default is 4)"
		cnt [integer!]
][
	cnt: any [cnt 4]
	parse value [
		some [
			opt [change copy indent some space (tabs (length? indent) / cnt)]
			thru newline
		]
	]
	value
]

set 'detab func [
	"Convert tabs to spaces (modifies)"
	value [string!] "Script to convert"
	/count			"Number of spaces in tab /default is 4)"
		cnt [integer!]
][
	cnt: any [cnt 4]
	parse value [
		some [
			opt [change copy indent some tab (spaces (length? indent) * cnt)]
			thru newline
		]
	]
	value
]
]
