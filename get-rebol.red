Red[]

#include %packers/tar.red
#include %../castr/http-scheme.red

get-rebol: func [
	/local links
] [
	links: [
		Linux http://www.rebol.com/downloads/v278/rebol-core-278-4-3.tar.gz
		Windows http://www.rebol.com/downloads/v278/rebol-core-278-3-1.exe
		OSX http://www.rebol.com/downloads/v278/rebol-core-278-2-5.tar.gz
	]
	paths: [
		Linux "releases/rebol-core/rebol"
		OSX
	]

	link: select links system/platform
	path: select paths system/platform

	; TODO this section must be platform specific
	data: load-tar read link
	data: select data path
	write/binary %rebol data
	call "chmod +x rebol"
	; -- return something
	true
]
