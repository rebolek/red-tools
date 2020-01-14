Red[
	Title: "File tools"
	Author: "Boleslav Březovský"
]

match: func [
	"Match string to given wildcard pattern (supports ? and *)"
	;TODO: escaping for * and ?
	value	[any-string!]
	pattern	[any-string!]
	/local forward
][
	forward: func [][
		value: next value
		pattern: next pattern
	]
	value: to string! value
	pattern: to string! pattern
	until [
		switch/default pattern/1 [
			#"?" [forward]
			#"*" [
				unless value: find value first pattern: next pattern [
					return false
				]
			]
		][
			either equal? value/1 pattern/1 [forward][return false]
		]

		tail? pattern
	]
	unless empty? value [return false]
	true
]

foreach-file: func [
	"Evaluate body for each file in a path"
	'file	[word!]
	path	[file!]
	body	[block!]
	/with "Wildcard based pattern file has to confort to"
		pattern	[any-string!]
	/local files f
][
	files: read path
	foreach f files [
		f: rejoin [path f]
		either dir? f [
			either with [
				foreach-file/with :file f body pattern
			][
				foreach-file :file f body
			]
		][
			if any [
				not with
				all [with match second split-path f pattern]
			][
				set :file f
				do body
			]
		]
	]
]
