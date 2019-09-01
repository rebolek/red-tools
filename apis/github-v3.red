Red [
	Title: "GitHub API implementation"
	Author: "Boleslav Březovský"
	Date: "5-3-2017"
	Usage: {
You must set GITHUB/USER and GITHUB/PASS to your username and password.
	}
]

do %../http-tools.red

map-each: function [
	'word ; NOTE: leaks word
	series
	body
] [
	forall series [
		set word series/1
		series/1: do bind body word
	]
	series
]

export: function [
	"Export words from object to global context"
	object
	words "Words in format: optional: SET-WORD! - new name, WORD! - word to export"
] [
	word: name: none
	parse words [
		some [
			(name: none)
			opt [set name set-word!]
			set word word!
			(
				unless name [name: word]
				set :name get in object word
			)
		]
	]
]

github: context [

; --- send

send: func [
	"Send request to Github API (GET by default)"
	data
	/method "Send different request type (POST, PUT, ...)"
		req-type
		request
	/full "Return raw data" ; TODO: rename
	/preview "Support preview features"
	/local link args-rule header-data header
] [
	method: either method [req-type] ['GET]
	link: make-url repend copy [https://api.github.com/] data
	header: copy [
		Accept: "application/vnd.github.v3+json"
		User-Agent: "Red-GitHub-API-v3"
	]
	if preview [header/Accept: "application/vnd.github.mercy-preview+json"]
	unless equal? 'GET method [
		insert header [
			Content-Type: "application/json"
		]
		request: to-json request
	]
	response: either verbose? [
		send-request/verbose/data/with/auth link method request header 'Basic reduce [form user pass]
	][
		send-request/data/with/auth link method request header 'Basic reduce [form user pass]
	]
	either full [response] [response/data]
]

; ---------------------------------

user: none
pass: none
response: none
verbose?: false

login: func [
	username
	password
] [
	user: username
	pass: password
	true ; so we won’t return password
]

; ---------------------------------

get-user: function [
	user "User's name"
] [
	send [%users name]
]

get-repos: function [
	user
] [
	send [%users user %repos]
]

comment {
	USAGE:

	make-gist %my-script.red "Super thing" ; loads %my-script.red

	}

; --- GIST ---

comment {
    Authentication
    Truncation
    List a user's gists 				- GET-GISTS
    List all public gists 				- N/A
    List starred gists 					- N/A
    Get a single gist 					- GET-GIST
    Get a specific revision of a gist 	- GET-GIST/REVISION
    Create a gist 						- MAKE-GIST
    Edit a gist 						- MAKE-GIST/UPDATE
    List gist commits 					- GIST-COMMITS
    Star a gist 						- N/A
    Unstar a gist 						- N/A
    Check if a gist is starred 			- N/A
    Fork a gist 						- FORK-GIST
    List gist forks 					- LIST-GIT-FORKS
    Delete a gist 						- N/A
    Custom media types
}

get-gists: func [
	user
] [
	send [%users user %gists]
]

get-gist: func [
	id
	/revision "Get specific revision" ; TODO: test it
		sha
	/local
		link
] [
	link: [%gists id]
	if revision [append link sha]
	send link
	response/data/files
]

make-gist: func [
	"Make new or update Gist on GitHub. Returns Gists' ID."
	data "Filename, or block of filenames"
	description "Gist description"
	/private "Should Gist be created as private?"
	/update "Update existing gist instead of creating new one"
		id
	/local files gist link
] [
	unless block? data [data: reduce [data]]
	files: make map! length? data
	foreach value data [
		files/(form value): make map! reduce [quote content: read value]
		; TODO: check for file existance, read/binary ?
	]

	gist: make map! reduce [
		quote description: description
		quote files: files
		quote public: true
	]

	link: either update [reduce [%gists id]] [%gists]
	; NOTE: It really doesn't matter if we use PATCH or POST for update(edit), but let's be nice
	send/method link either update ['PATCH]['POST] gist
	; TODO: error handling
	either update [
		id
	][
		last split response/data/html_url #"/"
	]
]

gist-commits: func ["Get gist commits" id] [send [%gists id %commits]]

fork-gist: func [id] [send/method [%gists id %forks] 'POST none]

get-git-forks: func [id] [send [%gists id %forks]]


save-gist: func [
	"Save gist to file"
	gist [map!] "Gist to save"
][
	foreach [file data] gist [
		write to file! data/filename data/content
	]
]

; --- COMMITS ---

comment {
    Get a Commit 					- GET-COMMIT
    Create a Commit  				- MAKE-COMMIT
    Commit signature verification 	- N/A
}

; GET /repos/:owner/:repo/git/commits/:sha

get-commit: func [
	repo [path!] "Repository in format owner/repo"
	sha
] [
	send [%repos repo %git %commits sha]
]

; POST /repos/:owner/:repo/git/commits

; message 	string 	Required. The commit message
; tree 		string 	Required. The SHA of the tree object this commit points to
; parents 	array of strings 	Required. The SHAs of the commits that were the parents of this commit. If omitted or empty, the commit will be written as a root commit. For a single parent, an array of one SHA should be provided; for a merge commit, an array of more than one should be provided.

make-commit: func [
	repo [path!] "Repository in format owner/repo"
	message
	tree
	parents
	; TODO: optional args author and commiter
] [
	unless block? parents [parents: reduce [parents]]
	send/method [%repos repo %git %commits] 'POST make map! reduce [
		quote message: message
		quote tree: tree
		quote parents: parents
	]
]

get-commits: func [
	repo [path!] "Repository in format owner/repo"
	/page "Get different page (first by default)"
		page-id
] [
	link: [%repos repo %commits]
	if page [
		append/only link compose [page: (page-id)]
	]
	send link
]

; --- TREES ---

comment {
    Get a Tree 				- GET-TREE
    Get a Tree Recursively	- GET-TREE/DEEP
    Create a Tree 			- MAKE-TREE
}

; GET /repos/:owner/:repo/gitget/trees/:sha

get-tree: func [
	repo [path!] "Repository in format owner/repo"
	sha
	/deep
	/local link
] [
	link: copy [%repos repo %git %trees sha]
	if deep [append link [? recursive: 1]]
	send link
]

make-tree: func [
	repo [path!] "Repository in format owner/repo"
	tree
] [
	; TODO: some checks if tree has necessary fields
	send/method [%repos repo %git %trees] 'POST tree
]

; --- BLOBS ---

; GET /repos/:owner/:repo/git/blobs/:sha

get-blob: func [
	repo [path!] "Repository in format owner/repo"
	sha
] [
	send [%repos repo %git %blobs sha]
]

; POST /repos/:owner/:repo/git/blobs

make-blob: func [
	repo [path!] 	"Repository in format owner/repo"
	content
	/encoding 		"Select encoding: base-64 or utf8 (default)"
		enc-type
] [
	unless enc-type [enc-type: 'utf8]
	send/method [%repos repo %git %blobs] 'POST make map! reduce [
		quote content: content
		quote encoding: enc-type
	]
]

; --- REFERENCES

make-reference: function [
	repo [path!] 	"Repository in format owner/repo"
	name [path!]	"Reference in format refs/heads/branch"
	sha
] [
	send/method [%repos repo %git %refs] 'POST make map! reduce [
		quote ref: form name
		quote sha: sha
	]
]

update-reference: function [
	repo [path!] 	"Repository in format owner/repo"
	name [path!]	"Reference in format heads/branch"
	sha
	/force
] [
;PATCH /repos/:owner/:repo/git/refs/:ref
	; FIXME: POST should be PATCH
	send/method [%repos repo %git %refs name] 'POST make map! reduce [
		quote sha: sha
		quote force: force
	]

]

get-reference: function [
	repo [path!] 	"Repository in format owner/repo"
	name [path!]	"Reference in format heads/branch"
	/all
] [
;GET /repos/:owner/:repo/git/refs/heads/skunkworkz/featureA
; GET /repos/:owner/:repo/git/refs
	send either all [
		[%repos repo %git %refs]
	] [
		[%repos repo %git %heads name]
	]
]

; ---

comment {
    List issues 					- GET-ISSUES
    List issues for a repository 	- GET-ISSUES
    Get a single issue 				- GET-ISSUE
    Create an issue 				- MAKE-ISSUE
    Edit an issue 					- EDIT-ISSUE ; TODO: needs PATCH
    Lock an issue 					- TODO: needs PUT
    Unlock an issue 				- TODO: needs DELETE
    Custom media types


* GET /issues
		List all issues assigned to the authenticated user across all visible repositories including owned repositories, member repositories, and organization repositories.
		You can use the filter query parameter to fetch issues that are not necessarily assigned to you. See the table below for more information.

* GET /user/issues
		List all issues across owned and member repositories assigned to the authenticated user.

* GET /orgs/:org/issues
		List all issues for a given organization assigned to the authenticated user.

* GET /repos/:owner/:repo/issues
		List issues for a repository


filter 	string 	Indicates which sorts of issues to return. Can be one of:
* assigned: Issues assigned to you
* created: Issues created by you
* mentioned: Issues mentioning you
* subscribed: Issues you're subscribed to updates for
* all: All issues the authenticated user can see, regardless of participation or creation
Default: assigned
state 	string 	Indicates the state of the issues to return. Can be either open, closed, or all. Default: open
labels 	string 	A list of comma separated label names. Example: bug,ui,@high
sort 	string 	What to sort results by. Can be either created, updated, comments. Default: created
direction 	string 	The direction of the sort. Can be either asc or desc. Default: desc
since 	string 	Only issues updated at or after this time are returned. This is a timestamp in ISO 8601 format: YYYY-MM-DDTHH:MM:SSZ.
}

get-issues: func [
	; TODO: see docs for difference between GET /issues and GET /user/issues
	"Get all user's issues"
	/user "Get all assigned issues"
	/repo "Get issues for repository"
		repo-name
	/org "Get issues for organization"
		org-name
	/total "Instead of issues return total number of pages"
	/page "Get different page (first by default)"
		page-id
	/with ; TODO
		filter
	/local count link 
][
	count: none
	link: copy case [
		user 	[[%issues]]
		org 	[[%orgs org-name %issues]]
		repo 	[[%repos form repo-name %issues]]
		true 	[[%user %issues]]
	]
	if page [
		append/only link compose [page: (page-id)]
	]
	if with [append/only link filter]
	ret: send/full link

	either total [
		Link: {<https://api.github.com/repositories/1449773/issues?page=2>; rel="next", <https://api.github.com/repositories/1449773/issues?page=14>; rel="last"}   
		; FIXME: this doesn't work at all
		parse ret/headers/link [thru "next" thru "page=" copy count to #">"]
		to integer! count
	] [
		ret/data
	]
]

get-issue: function [
	repo
	number
] [
	send [%repos repo %issues number]
]

comment {
		title 		string 				Required. The title of the issue.
		body 		string 				The contents of the issue.
		assignee 	string 				Login for the user that this issue should be assigned to. NOTE: Only users with push access can set the assignee for new issues. The assignee is silently dropped otherwise. This field is deprecated.
		milestone 	integer 			The number of the milestone to associate this issue with. NOTE: Only users with push access can set the milestone for new issues. The milestone is silently dropped otherwise.
		labels 		array of strings 	Labels to associate with this issue. NOTE: Only users with push access can set labels for new issues. Labels are silently dropped otherwise.
		assignees 	array of strings 	Logins for Users to assign to this issue. NOTE: Only users with push access can set assignees for new issues. Assignees are silently dropped otherwise.
}

make-issue: function [
	repo
	title
	body
	/assignee
		names [string! block!]
	/label
		labels
	/milestone
		milestone-id

] [
	; POST /repos/:owner/:repo/issues
	header: reduce [
		quote title: title
		quote body: body
	]
	names: trim reduce [names]
	case/all [
		1 = length? names 	(repend header [quote assignee: first names])
		1 < length? names 	(repend header [quote assignees: names])
		label 				(repend header [quote label: labels])
		milestone 			(repend header [quote milestone: milestone-id])
	]
	send/method [%repos repo %issues] 'POST header
]

comment {
		title 		string 				The title of the issue.
		body 		string 				The contents of the issue.
		assignee 	string 				Login for the user that this issue should be assigned to. This field is deprecated.
		state 		string 				State of the issue. Either open or closed.
		milestone 	integer 			The number of the milestone to associate this issue with or null to remove current. NOTE: Only users with push access can set the milestone for issues. The milestone is silently dropped otherwise.
		labels 		array of strings 	Labels to associate with this issue. Pass one or more Labels to replace the set of Labels on this Issue. Send an empty array ([]) to clear all Labels from the Issue. NOTE: Only users with push access can set labels for issues. Labels are silently dropped otherwise.
		assignees 	array of strings 	Logins for Users to assign to this issue. Pass one or more user logins to replace the set of assignees on this Issue. Send an empty array ([]) to clear all assignees from the Issue. NOTE: Only users with push access can set assignees for new issues. Assignees are silently dropped otherwise.
}

edit-issue: function [
	; TODO: needs PATCH
] [
	; PATCH /repos/:owner/:repo/issues/:number
]

; --- REPOSITORIES

comment {
	List your repositories 			- GET-REPOS
	List user repositories 			- GET-REPOS/BY user
	List organization repositories 	- GET-REPOS/BY org
	List all public repositories 	- GET-REPOS/ALL
	Create 							- MAKE-REPO
	Get 							- GET-REPO
	Edit 							- EDIT-REPO
	List contributors
	List languages
	List Teams
	List Tags
	Delete a Repository
}

comment {
	GET-REPOS parameters:

		visibility 		string 	Can be one of all, public, or private. Default: all
		affiliation 	string 	Comma-separated list of values. Can include:
									* owner: Repositories that are owned by the authenticated user.
									* collaborator: Repositories that the user has been added to as a collaborator.
									* organization_member: Repositories that the user has access to through being a member of an organization. This includes every repository on every team that the user is on.
								Default: owner,collaborator,organization_member
		type 			string 	Can be one of all, owner, public, private, member. Default: all
								Will cause a 422 error if used in the same request as visibility or affiliation.
		sort 			string 	Can be one of created, updated, pushed, full_name. Default: full_name
		direction 		string 	Can be one of asc or desc. Default: when using full_name: asc; otherwise desc

}

get-repos: function [

] [

]

get-repo: function [
	repo
] [
	send [%repos repo]
]

get-repo-content: function [
	repo
	path
] [
;GET /repos/:owner/:repo/contents/:path
	send [%repos repo %contents path]
]

; --- tools

find-file: function [
	"Find file in tree and return tree object"
	tree
	file
] [
	print ["Find" mold file]
	foreach obj tree/tree [
		all [
			equal? "blob" obj/type
			equal? form file obj/path
			return obj
		]
	]
]

commit: func [
	repo [path!] 	"Repository in format owner/repo"
	files
	message
] [
{
    1. get the current commit object
    2. retrieve the tree it points to
    3. retrieve the content of the blob object that tree has for that particular file path
    4. change the content somehow and post a new blob object with that new content, getting a blob SHA back
    5. post a new tree object with that file path pointer replaced with your new blob SHA getting a tree SHA back
    6. create a new commit object with the current commit SHA as the parent and the new tree SHA, getting a commit SHA back
    7. update the reference of your branch to point to the new commit SHA
}
	unless block? files [files: reduce [files]]

	; -- 1. get the current commit object
	; TODO: should be done by PULL
	commits: list-commits repo
	_commit: first commits ; I hope order is guaranteed
	; -- 2. retrieve the tree it points to
	tree: get-tree repo _commit/commit/tree/sha

	foreach file files [
		tree-file: find-file tree file
	; -- 3. retrieve the content of the blob object that tree has for that particular file path
	;	NOTE: why do I retrieve the blob? I am not reusing it, AFAIK
		blob: get-blob repo tree-file/sha
	; -- 4. change the content somehow and post a new blob object with that new content, getting a blob SHA back
		content: read file
		new-blob: make-blob repo content ; TODO: expects textfiles, does not handle binary files yet
		blob/sha: new-blob/sha
	;	blob/content: content
	]
	; -- 5. post a new tree object with that file path pointer replaced with your new blob SHA getting a tree SHA back
	tree/base_tree: tree/sha
	tree/sha: none
	tree/url: none
	tree: make-tree repo tree
	; -- 6. create a new commit object with the current commit SHA as the parent and the new tree SHA, getting a commit SHA back
	new-commit: make-commit repo message tree/sha _commit/sha
	; -- 7. update the reference of your branch to point to the new commit SHA
	update-reference repo 'heads/master new-commit/sha ; TODO: support other branches

]

search: func [
	query
	type "repositories, commits, code, issues, topics, labels"
	/sort
		sorting "stars, forks, updated"
	/order
		ordering "asc, desc"
	/local data
][
	unless find [repositories commits code issues topics labels] type [
		do make error! "Searching for unsupported type of information"
	]
	type: to file! type
	data: [q: query]
	if find [stars forks updated] sorting [append data [sort: sorting]]
	if find [asc desc] order [append data [order: ordering]]
	send [%search type data]
]

licenses: [
	{Academic Free License v3.0} 	afl-3.0
	{Apache license 2.0} 	apache-2.0
	{Artistic license 2.0} 	artistic-2.0
	{Boost Software License 1.0} 	bs1-1.0
	{BSD 2-clause "Simplified" license} 	bsd-2-clause
	{BSD 3-clause "New" or "Revised" license} 	bsd-3-clause
	{BSD 3-clause Clear license} 	bsd-3-clause-clear
	{Creative Commons license family} 	cc
	{Creative Commons Zero v1.0 Universal} 	cc0-1.0
	{Creative Commons Attribution 4.0} 	cc-by-4.0
	{Creative Commons Attribution Share Alike 4.0} 	cc-by-sa-4.0
	{Do What The F*ck You Want To Public License} 	wtfpl
	{Educational Community License v2.0} 	ecl-2.0
	{Eclipse Public License 1.0} 	epl-1.0
	{European Union Public License 1.1} 	eupl-1.1
	{GNU Affero General Public License v3.0} 	agpl-3.0
	{GNU General Public License family} 	gpl
	{GNU General Public License v2.0} 	gpl-2.0
	{GNU General Public License v3.0} 	gpl-3.0
	{GNU Lesser General Public License family} 	lgpl
	{GNU Lesser General Public License v2.1} 	lgpl-2.1
	{GNU Lesser General Public License v3.0} 	lgpl-3.0
	{ISC} 	isc
	{LaTeX Project Public License v1.3c} 	lppl-1.3c
	{Microsoft Public License} 	ms-pl
	{MIT} 	mit
	{Mozilla Public License 2.0} 	mpl-2.0
	{Open Software License 3.0} 	osl-3.0
	{PostgreSQL License} 	postgresql
	{SIL Open Font License 1.1} 	ofl-1.1
	{University of Illinois/NCSA Open Source License} 	ncsa
	{The Unlicense} 	unlicense
	{zLib License} 	zlib
]

; --- end of context

]


; some user functions:

load-gist: function [
	"Load Gist as Red file"
	id
] [
	; NOTE: this expects that gist is one file only and does the first file
	;		should be user-configurable somehow probably
	if url? id [id: last split id #"/"]
	gist: github/get-gist id
	load select select gist first keys-of gist 'content
]
























