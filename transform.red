Red[
	Title: "Transform"
	Author: "Boleslav Březovský"
	Purpose: "Translate received JSON object to Red function call"
	Notes: {
Maps received JSON object into Red function call.
Finds matching sequence of required keys and calls related function with keys'
values as arguments.
}
	To-Do: [
		error-handling:
			"nothing matched when NONE option is not present"
			"check for required fields"
			[required "user" "pass" ["required fields missing"]]
			{block is executed and returned, it can be just a string for an 
			error message, or some function}
			"this boils down to two options of handling required fields:"
			#1	[
					"user" "pass" [login "user" "pass"]
				]
				{on fail it returns something like "nothing matched" or NONE}

			#2	[
					required "user" "pass"	["required fields missing"]
					"user" "pass"			[login "user" "pass"]
				]

			"There is also third option, provide optional error message:"
			#3	[
					"user" "pass" [login "user" "pass"]["required fields missing"]
				]
	]
]


mapping: [
	#none					[list]
	state					[list/only state]
	location				[list/codes location]
	state location			[list/only/codes state location]
	scraper					[list/with scraper]
	scraper state			[list/only/with state scraper]
	scraper location		[list/codes/with location scraper]
	scraper state location	[list/only/codes/with state location scraper]
]

request: #(state: "CA" location: "Los Angeles")

#call [transform mapping request]
#result [list/only/codes "CA" "Los" "Angleles"]

transform: func [
	"Map JSON request to a function call"
	mapping [block!]
	request [string! map!] "JSON object or converted map!"
	/local key keys value break? rule word words action
][
	unless map? request [request: load-json request]
	keys: sort keys-of request

	all-words: unique parse mapping [
		collect [some [#none | keep word! | skip]]
	]
	remove-each key keys [not find all-words key]

	break?: false
	rule: [
		(words: clear [])
		some [set word word! (append words word)]
		set action block!
		(if equal? sort words keys [break?: true])
	]
	parse mapping [
		some [
			if (break?) break
		|	'none set action block! (if empty? keys [break?: true])
		|	rule
		]
	]
	foreach key keys [replace/all action key request/:key]
	action
]
