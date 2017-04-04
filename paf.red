Red [
	Title: "PAF - parse files"
	Author: "Boleslav Březovský"
] 

paf: function [
	path
	pattern
	/quiet	"Do not print any output"
	/only	"Return only logic! value to indicate match"
] [
	matches: make block! 100
	lines: 1
	found?: false
	line-start: none
	mark: none
	dir: none
	filepath: none
	unless dir? path [append path #"/"]
	dirs: reduce copy [path]
	find-line-end: function [
		text
	] [
		unless mark: find text newline [mark: tail text]
		mark
	]
	pattern: compose/deep [
		some [
			(either block? pattern [append/only copy [] pattern] [pattern]) 
			mark:
			(quote (
				found?: true
				unless only [append last matches mark]
				unless quiet [
					print rejoin [
						filepath #"@" lines ": " 
						copy/part line-start find-line-end mark
					]
				]
			)) 
		;	to end
		|	#"^/" line-start: (quote (lines: lines + 1))
		|	skip
		]
	]
	scan-file: func [
		path
	] [
		lines: 1
		unless error? try [file: read path] [
			unless only [repend matches [path make block! 100]]
			parse file pattern
			all [
				not only empty? 
				last matches
				remove/part skip tail matches -2 2
			]
		]
	]
	scan-dir: func [
		path
	] [
		dir: read path
		foreach file dir [
			either dir? file [
				append dirs file
				scan-dir to file! dirs
				take/last dirs
			] [
				scan-file filepath: append to file! dirs file
			]
		]
	]
	scan-dir path
	either only [found?] [matches]
]
