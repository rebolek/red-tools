Red [
	Title: "GitHub API v4"
	Author: "Boleslav Březovský"
]

do %json.red
do %graphql.red
do %http-tools.red

; === Query ==================================================================

; type description (taken from https://developer.github.com/v4/reference/query/)

connections: [
	first 	[integer!] 		; Returns the first n elements from the list.
	after 	[string!]		; Returns the elements in the list that come after the specified global ID.
	last	[integer!]		; Returns the last n elements from the list.
	before	[string!] 		; Returns the elements in the list that come before the specified global ID.
	query 	[string!]		; The search string to look for.
	type 	[search-type!] 	; The types of search items to search within.
]

fields: [
	codeOfConduct [
		"Look up a code of conduct by its key"
		key 	[string!] "The code of conduct's key"
	]		
	codesOfConduct [
		"Look up a code of conduct by its key"
	]
	node [
		"Fetches an object given its ID"
		id 		[id!] "ID of the object"
	]
	nodes [
		"Lookup nodes by a list of IDs"
		ids 	[some id!] "The list of node IDs"
	]
	organization [
		"Lookup a organization by login"
		login 	[string!] "The organization's login"
	]
	rateLimit [
		"The client's rate limit information"
	]
	relay [
		"Hack to workaround https://github.com/facebook/relay/issues/112 re-exposing the root query object"
	]
	repository [
		"Lookup a given repository by the owner and repository name"
		owner 	[string!] "The login field of a user or organization"
		name 	[string!] "The name of the repository"
	]
	repositoryOwner [
		"Lookup a repository owner (ie. either a User or an Organization) by login"
		login 	[string!] "The username to lookup the owner by"
	]
	resource [
		"Lookup resource by a URL"
		url 	[url!] "The URL"
	]
	topic [
		"Lookup a topic by name"
		name 	[string!] "The topic's name"
	]
	user [
		"Lookup a user by login"
		login 	[string!] "The user's login"
	]
	viewer [
		"The currently authenticated user"
	]
]

sanitize: func [
	"Perform some escaping and optimization"
	string [string!]
] [
	parse trim string [
		some [
			change #"^"" {\"} 
		|	change #"^/" {} 	; TODO: change to escaping?
		| 	skip
		]
	]
	string
]

github: func [
	query
	/var
		vars
] [
	if block? query [query: graphql/encode query]
	unless string? vars [vars: json/encode vars]
	query: rejoin [{^{"query": "} sanitize query {"^}}]
	if vars [
		insert back tail query rejoin [{, "variables": } trim/lines vars]
	]
	send-request/data/auth https://api.github.com/graphql 'POST query 'Bearer token
]


; Testing:
;
; (set TOKEN in global context (temporary))
;
; ret: github graphql/encode test-query
;
; var example:
;
; ret: github/var graphql/encode [query ('number_of_repos Int!) [viewer [name repositories (last: :number_of_repos) [nodes [name]]]]] json/encode #(number_of_repos 3)
;
;
; ---
;
; d: {{"query":"query { viewer { login}}"}}
; r: send-request/data/auth https://api.github.com/graphql 'POST d 'Bearer token
