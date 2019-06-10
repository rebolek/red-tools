Red[]

do %apis/github-v3.red
do %github-options.red

get-issues: func [
	/local page issues repo
] [
	issues: copy []
	repo: 'red/red
	; get last 30 issues
	page: github/get-issues/repo/with repo [state: 'all]
	; get total page count
	print ["Downloading" page/1/number "issues."]
	pages: page/1/number / 30
	append issues page
	repeat page pages [
		print ["page" page]
		append issues github/get-issues/repo/page/with repo page + 1 [state: 'all]
	]
	issues
]

get-commits: func [
	/local page commits repo
][
	commits: copy []
	page: 1
	repo: 'red/red
	until [
		data: github/get-commits/page repo probe page
		append commits data
		page: page + 1
		empty? data
	]
	commits
]

; --- functions working on downloaded data

get-column: func [
	data
	column
	/local line result value
][
	result: copy []
	foreach line data [
		value: pick line column
		unless find result value [append result value]
	]
	result
]

get-authors: func [
	issues
	/local
][
	authors: make map! []
	foreach issue issues [
		author: issue/user/login
		either authors/:author [authors/:author: authors/:author + 1][authors/:author: 1]
	]
	authors
]

get-fixes: func [
	"Return commits that are fixes to issues (message contains #XXXX)"
	commits
	/local fixes
][
	fixes: copy []
	numbers: charset "0123456789"
	foreach commit commits [
		issue: none
		parse commit/commit/message [thru #"#" copy issue some numbers]
		if issue [repend fixes [issue commit]]
	]
	fixes
]

get-issue-by-number: func [
	issues
	number
][
	foreach issue issues [
		if equal? issue/number number [return issue]
	]
	none
]

get-aoiltf: func [
"get authors of issues leading to fixes"
	commits
	issues
][
	authors: make map! []
	fixes: get-fixes commits
	foreach [id commit] fixes [
		id: to integer! id
		if issue: get-issue-by-number issues id [
			; NOTE: some messages may point to non-existent issue (because they point to something different, see commit "bc6d27c1d0ae89237ce9cbddb7fe593924d482e8")
			author: issue/user/login
			either authors/:author [
				append authors/:author id ;TODO: or issue directly, let's see
			][
				authors/:author: reduce [id]
			]
		]
	]
	authors
]
