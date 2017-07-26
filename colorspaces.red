Red[
	Title: 		"Colorspaces"
	File: 		%colorspaces.red
	Author: 	"Boleslav Březovský"
	Date:		3-4-2014
	Version: 	0.0.1
]

minimum-of: func [block] [first sort copy block]
maximum-of: func [block] [last sort copy block]

to-hsl: func [
	color [tuple!]
	/local min max delta alpha total
][
	if 4 = length? color [alpha: color/4 / 255.0]
	color: context [r: color/1 / 255.0 g: color/2 / 255.0 b: color/3 / 255.0]
	min: minimum-of values-of color
	max: maximum-of values-of color
	delta: max - min
	total: max + min
	local: object [h: s: l: to percent! total / 2.0]
	do bind bind [
		either zero? delta [h: s: 0.0] [
			s: to percent! either l > .5 [2.0 - max - min] [delta / total]
			h: 60.0 * switch max reduce [
				r [g - b / delta + either g < b [6.0] [0.0]]
				g [b - r / delta + 2.0]
				b [r - g / delta + 4.0]
			]
		]
	] color local
	local: values-of local
	if alpha [append local alpha]
	local
]

to-hsv: func [
	color [tuple!]
	/local min max delta alpha
][
	if 4 = length? color [alpha: color/4 / 255.0]
	color: context [r: color/1 / 255.0 g: color/2 / 255.0 b: color/3 / 255.0]
	min: minimum-of values-of color
	max: maximum-of values-of color
	delta: max - min
	local: object [h: s: v: to percent! max]
	do bind bind [
		either zero? delta [h: s: 0.0] [
			s: to percent! either delta = 0.0 [0.0] [delta / max]
			h: 60.0 * switch max reduce [
				r [g - b / delta + either g < b [6.0] [0.0]]
				g [b - r / delta + 2.0]
				b [r - g / delta + 4.0]
			]
		]
	] color local
	local: values-of local
	if alpha [append local alpha]
	local
]


load-hsl: func [
	color [block!]
	/local alpha c x m i
][
	if color/4 [alpha: color/4]
	; LOCAL: HSL, COLOR: RGB
	bind/new [h s l] local: object []
	set words-of local color
	bind/new [r g b] color: object []
	do in local [
		i: h / 60
		c: 1 - (abs 2 * l - 1) * s
		x: 1 - (abs -1 + mod i 2) * c
		m: l - (c / 2)
	]
	do in color [
		set [r g b] reduce switch to integer! i [
			0 [[c x 0]]
			1 [[x c 0]]
			2 [[0 c x]]
			3 [[0 x c]]
			4 [[x 0 c]]
			5 [[c 0 x]]
		]
	]
	color: to tuple! map-each value values-of color [to integer! round m + value * 255]
	if alpha [color/4: alpha * 255]
	color
]

load-hsv: func [
	color [block!]
	/local alpha c x m i
][
	if color/4 [alpha: color/4]
	; LOCAL: HSV, COLOR: RGB
	bind/new [h s v] local: object []
	set words-of local color
	bind/new [r g b] color: object []
	do in local [
		i: h / 60
		c: v * s
		x: 1 - (abs -1 + mod i 2) * c
		m: v - c
	]
	do in color [
		set [r g b] reduce switch to integer! i [
			0 [[c x 0]]
			1 [[x c 0]]
			2 [[0 c x]]
			3 [[0 x c]]
			4 [[x 0 c]]
			5 [[c 0 x]]
		]
	]
	color: to tuple! map-each value values-of color [to integer! round m + value * 255]
	if alpha [color/4: alpha * 255]
	color
]

color!: object [
	rgb: 0.0.0.0
	web: #000000
	hsl: make block! 4
	hsv: make block! 4
]

new-color: does [make color! []]

set-color: func [
	color 	[object!] "Color object"
	value	[block! tuple! issue!]
	type 	[word!]
] [
	switch type [
		rgb [
			do in color [
				rgb: value
				web: to-hex value
				hsl: to-hsl value
				hsv: to-hsv value
			]
		]
		web [
			do in color [
				rgb: to tuple! value
				web: value
				hsl: to-hsl rgb
				hsv: to-hsv rgb
			]
		]
		hsl [
			do in color [
				rgb: load-hsl value
				web: to-hex rgb
				hsl: value
				hsv: to-hsv load-hsv value
			]
		]
		hsv [
			do in color [
				rgb: load-hsv value
				web: to-hex rgb
				hsl: to-hsl load-hsv value
				hsv: value
			]
		]
	]
	color
]

;apply-color color 'saturate 50%

apply-color: func [
	"Apply color effect on color"
	color 	[object!] 	"Color! object"
	effect 	[word!]		"Effect to apply"
	amount 	[number!]	"Effect amount"
] [
	effect: do bind select effects effect 'amount
	set-color color color/:effect effect
]

effects: [
	; return changed colorspace
	darken [
		color/hsl/3: max 0% color/hsl/3 - amount
		'hsl
	]
	lighten [
		color/hsl/3: min 100% color/hsl/3 + amount
		'hsl
	]
	saturate [
		color/hsl/2: min 100% max 0% color/hsl/2 + amount
		;color/hsv/2: color/hsv/2 + (100% - color/hsv/2 * amount)
		'hsl
	]
	desaturate [
		color/hsl/2: min 100% max 0% color/hsl/2 - amount
		'hsl
	]
	hue [
		color/hsl/1: color/hsl/1 + amount // 360
		'hsl
	]
]