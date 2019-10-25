Red[]

nanotest: context [
	passed: failed: log: none
	assertions: 0

	results: #(
		total: #(pass: 0 fail: 0 error: 0)
		group: #(pass: 0 fail: 0 error: 0)
		test: #(pass: 0 fail: 0 error: 0)
	)
	state: none

	set 'group func [
		name [string!]
	][
		; close last group
		if any [ ; at least one test must've run
			results/group/pass > 0
			results/group/fail > 0
			results/group/error > 0
		][
			repend log [now/precise #END-GROUP load form body-of results/group]
		]

		; start new group
		results/group/pass: results/group/fail: results/group/error: 0
		repend log [now/precise #START-GROUP name]
;		print ["^/=== GROUP: " name " ==="]
	]

	set 'test func [
		name [string!]
		code [block!]
	][
		results/test/pass: results/test/fail: results/test/error: 0
		repend log [now/precise #START-TEST name]
		result: try code
		repend log [
			now/precise 
			either error? result [
				reduce ['error result]
			][
				load form body-of results/test
			]
		]
		print message
	]

	set 'assert func [
		result [logic!]
	][
		either result [
			results/test/pass: results/test/pass + 1
		][
			results/test/fail: results/test/fail + 1
		]
	]


	set 'test-log func [
	][
		foreach [time message] log [
			print [time message]
		]
	]
]
