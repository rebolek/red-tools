Red[]

do %../jwt.red

header: #("alg" "HS256" "typ" "JWT")
payload: #("sub" "1234567890" "name" "John Doe" "iat" 1516239022)
secret: "mojetajneheslo"


probe equal? 
	to-jwt payload secret
	{eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.HZnzK2uTJ3S-j4yXT9gDUE8W1s9cxb7Hyg1ZD_0djR0}
