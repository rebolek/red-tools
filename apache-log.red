Red[]

map-from: func [
	words
	/local result
][
	result: make map! []
	foreach word words [
		result/:word: get word
	]
	result
]

parse-apache-time: func [
	data
	/local sign tz tz-hour tz-min value
][
	; NOTE: Expects English names in system/locale
	get-month: func [month][
		months: system/locale/months
		forall months [
			if equal? month copy/part first months 3 [
				return index? months
			]
		]
	]
	date: now ; prefill with something
	date/timezone: 0
	parse data [
		#"["
		copy value to slash skip (date/day: load value)
		copy value to slash skip (date/month: get-month value)
		copy value to #":" skip (date/year: load value)
		copy value to #":" skip (date/hour: load value)
		copy value to #":" skip (date/minute: load value)
		copy value to space skip (date/second: load value)
		set sign skip
		copy tz-hour 2 skip
		copy tz-min 2 skip (
			tz: to time! probe reduce [load tz-hour load tz-min]
			if equal? #"-" sign [tz: negate tz]
			date/timezone: tz
		)
		#"]"
	]
	date
]

parse-log: func [
	log [string!]
	/local result
][
	result: copy []
	log: split log newline
	foreach line log [
		append result parse-line line
	]
	result
]

test-line: {162.158.75.158 - - [04/Jun/2018:07:01:36 +0000] "GET / HTTP/1.1" 301 562 "-" "Mozilla/5.0 (Linux; Android 6.0.1; Nexus 5X Build/MMB29P) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2272.96 Mobile Safari/537.36 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"}

parse-line: func [
	line [string!]
][
	parse line [
		copy ip to space skip (ip: to tuple! ip)
		copy identd to space skip (identd: load identd)
		copy userid to space skip (userid: load userid)
		copy date thru #"]" skip (date: parse-apache-time date)
		skip copy request to #"^"" 2 skip
		copy status to space skip (status: to integer! status)
		copy size to space skip (size: to integer! size)
		copy referrer to space skip (referrer: load referrer)
		copy agent to end (agent: load agent)
	]
	map-from [ip identd userid date request status size referrer agent]
]