Red [
	Title: "PAF - parse files"
] 

paf: function [
	path
	pattern
	/quiet
] [
	matches: make block! 100
	lines: 1
	found?: false
	line-start: none
	mark: none
	dir: none
	filepath: none
	found: copy []
	unless dir? path [append path #"/"]
	dirs: reduce copy [path]
	find-line-end: function [
		text
	] [
		unless mark: find text newline [mark: tail text]
		mark
	]
	pattern: compose/deep [
		(quote (lines: 1))
		some [
			(either block? pattern [append/only copy [] pattern] [pattern]) 
			mark:
			(quote (
				append last matches mark
				unless quiet [print rejoin [filepath #"@" lines ": " copy/part line-start find-line-end mark]]
			)) 
		;	to end
		|	#"^/" line-start: (quote (lines: lines + 1))
		|	skip
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
				found?: false
				filepath: append to file! dirs file
				unless error? try [file: read filepath] [
					repend matches [filepath make block! 100]
					parse file pattern
					if empty? last matches [remove/part skip tail matches -2 2]
				]
			]
		]
	]
	scan-dir path
	matches
]
