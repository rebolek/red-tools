Red[]

context [
	passed: failed: log: none

	set 'assert func [
		result [logic!]
	][
		unless log [init-test]
		either result [
			passed: passed + 1
		][
			failed: failed + 1
		]
	]

	set 'init-test does [
		passed: failed: 0
		log: copy []
	]

	set 'test func [
		name [string!]
		code [block!]
	][
		result: do code
		message: rejoin ["TEST: " name " - " either result ["passed"]["failed"]]
		repend log [now message]
		print message
	]
]

httpbin: https://httpbin.org/

test "GET: basic request" [
	ret: send-request httpbin/get 'GET
	assert 200 = ret/code
]

test "GET: basic form" [
	ret: send-request/data httpbin/get 'GET [x: 1 y: 2]
	assert 200 = ret/code
	assert ret/data/args = #(x: "1" y: "2")
]

test "GET: basic form with spaces" [
	ret: send-request/data httpbin/get 'GET [x: "hello world"]
	assert 200 = ret/code
	assert ret/data/args = #(x: "hello world")
]

test "POST: basic request" [
	ret: send-request/data httpbin/post 'POST [x: 1 y: 2]
	assert 200 = ret/code
	assert ret/data/form = #(x: "1" y: "2")
]
