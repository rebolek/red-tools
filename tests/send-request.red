Red[]

do %../nanotest.red

httpbin: https://httpbin.org/

group "GET"

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

group "POST"

test "POST: basic request" [
	ret: send-request/data httpbin/post 'POST [x: 1 y: 2]
	assert 200 = ret/code
	assert ret/data/form = #(x: "1" y: "2")
]

test "POST: JSON request" [
	ret: send-request/data httpbin/post 'POST #(x: 1 y: 2)
	assert 200 = ret/code
	assert ret/data/json = #(x: "1" y: "2")
]

group "AUTH"

test "AUTH: Basic authentication" [
	ret: send-request/auth httpbin/basic-auth/user/pass 'GET 'basic ["user" "pass"]
	assert 200 = ret/code
	assert ret/data = #(authenticated: true user: "user")
]

test "AUTH: Bearer" [
	ret: send-request/auth httpbin/basic-auth/user/pass 'GET 'bearer "deadcafe"
	; TODO: How to get 200 response?
;	assert 200 = ret/code
;	assert ret/data = #(authenticated: true user: "user")
]
