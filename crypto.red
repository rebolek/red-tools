Red[]

encrypt: func [
    data
    key
][
    data: to binary! data
    print ["length:" length? data]
    key: checksum key 'sha256
    padding-length: probe 32 - ((length? data) // 32) - 1
    padding: probe collect/into [loop padding-length [keep random/secure 255]] copy #{}
    insert padding padding-length
    insert data padding
    print ["length:" length? data]
    collect/into [
        loop probe (length? data) / 32 [keep key xor to binary! take/part data 32]
    ] copy #{}
]

decrypt: func [
    data
    key
][
    data: copy data
    key: checksum key 'sha256
    result: collect/into [
        loop (length? data) / 32 [keep key xor take/part data 32]
    ] copy #{}
    remove/part result 1 + first result
    to string! result
]