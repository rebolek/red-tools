Red[]

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