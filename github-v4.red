Red [
	Title: "GitHub API v4"
	Author: "Boleslav Březovský"
]

do %json.red
do %graphql.red
do %http-tools.red

github: context [

	token: none
	result: none

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
		parse string [
			some [
				change #"^"" {\"} 
			|	change #"^/" {} 	; TODO: change to escaping?
			| 	skip
			]
		]
		string
	]

; === main function ==========================================================

	send: func [
		query
		/var
			vars
	] [
		if block? query [query: graphql/encode query]
		if all [var not string? vars] [vars: json/encode vars]
		query: rejoin [{^{"query": "} sanitize query {"^}}]
		if vars [
			insert back tail query rejoin [{, "variables": } trim/lines vars]
		]
		result: send-request/data/auth https://api.github.com/graphql 'POST probe query 'Bearer token
		result/data
	]
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


; Usage
;
; get repository: 
;
;query {
;  organization(login: "red") {
;    name
;    url
;    repository(name: "red") {
;      name
;    }
;  }
;}
;
; query [organization (login: "red") [name url repository (name: "red") [name]]]
;
; get last 10 issues (title):
;
;query {
;  organization(login: "red") {
;    name 	; not required
;    url 	; not required
;    repository(name: "red") {
;      name
;      issues (last: 10) {edges {node {title}}}
;    }
;  }
;}
;
; query [organization (login: "red") [repository (name: "red") [issues (last: 10) [edges [node [title]]]]]]


; add comment to issue:
;query FindIssueID {
;  repository(owner:"rebolek", name:"red-tools") {
;    id
;    issue(number:1) {
;      id
;    }
;  }
;}
; 
; NOTE: subjectId is (issue) id from above query, clientMutationId is (repository) id
;
;mutation AddCommentToIssue {
;  addComment(input: {subjectId: "MDU6SXNzdWUyMzEzOTE1NTE=", body: "testing comment", clientMutationId: "MDEwOlJlcG9zaXRvcnk3OTM5MjA0OA=="}) {
;		clientMutationId
;  }
;}
;
; red version:
;
; query FindIssueId [repository (owner: "rebolek" name: "red-tools") [issue (number: 1) [id]]]
; mutation AddCommentToIssue [
;	addComment (input: [subjectId: "MDU6SXNzdWUyMzEzOTE1NTE=" clientMutationId: "MDEwOlJlcG9zaXRvcnk3OTM5MjA0OA==" body: "it works!"]) [
;	  clientMutationId	
;	]
; ]

comment-issue: function [
	repo
	issue-id
	text
	; usage: comment-issue 'owner/repo 123 "blablabla"
] [
	reply: github/send reduce [
		'query 'FindIssueId reduce [
			'repository to paren! compose [
				owner: (form repo/1) name: (form repo/2)
			]
			reduce ['id 'issue to paren! compose [number: (issue-id)] [id]]
		]
	]
	if equal? "Bad credentials" reply/message [
		; TODO: Use `cause-error` here, once I understand it
		return make error! "Bad credentials"
	]
	input: make map! compose [
		subjectId: (reply/data/repository/issue/id) 
		clientMutationId: (reply/data/repository/id)
		body: (text)
	]
	reply: github/send reduce [
		'mutation 'AddCommentToIssue reduce [
			'addComment to paren! compose/deep [input: (input)] [clientMutationId]
		]
	]
	; return mutation-id (or something else? who knows...)
	reply/data/addComment/clientMutationId
]