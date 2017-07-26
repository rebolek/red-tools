Red[
	Title: 		"Colorspaces"
	File: 		%colorspaces.red
	Author: 	"Boleslav Březovský"
	Date:		26-7-2017
	Version: 	0.0.2
	History:    [
		0.0.2 26-7-2017 "Rewritten to Red"
		0.0.1 3-4-2014 "Initial version"
	]
]

minimum-of: func [block] [first sort copy block]
maximum-of: func [block] [last sort copy block]
abs: :absolute

if equal? checksum mold :to-hex 'SHA1 #{B5C54B7F72B13EA037F366B3EB464DC46617210A} [
	; Make sure we are not redefining already redefined func
	to-hex*: :to-hex
	to-hex: function [
		"Patched TO-HEX with tuple! support" ; NOTE: tuple is expected to have length 3
		value
		/size
			length
	] [
		unless size [length: 8]
		if tuple? value [
			value: (65536 * value/1) + (256 * value/2) + value/3
		]
		to-hex*/size value length
	]
]



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
	if 4 = length? color [alpha: color/4 / 255.0]
	; LOCAL: HSL, COLOR: RGB
	local: context [h: s: l: none]
	set words-of local color
	color: context [r: g: b: none]
	do bind [
		i: h / 60.0
		c: 1.0 - (abs 2.0 * l - 1.0) * s
		x: 1.0 - (abs -1.0 + mod i 2.0) * c
		m: to float! l - (c / 2.0)
	] local
	do bind [
		set [r g b] reduce switch to integer! i [
			0 [[c x 0]]
			1 [[x c 0]]
			2 [[0 c x]]
			3 [[0 x c]]
			4 [[x 0 c]]
			5 [[c 0 x]]
		]
	] color
	color: make tuple! collect [foreach value values-of color [keep round m + value * 255]]
	if alpha [color/4: alpha * 255]
	color
]

load-hsv: func [
	color [block!]
	/local alpha c x m i
][
	if 4 = length? color [alpha: color/4 / 255.0]
	; LOCAL: HSL, COLOR: RGB
	local: context [h: s: v: none]
	set words-of local color
	color: context [r: g: b: none]
	do bind [
		i: h / 60.0
		c: v * s
		x: 1.0 - (abs -1.0 + mod i 2.0) * c
		m: to float! v - c
	] local
	do bind [
		set [r g b] reduce switch to integer! i [
			0 [[c x 0]]
			1 [[x c 0]]
			2 [[0 c x]]
			3 [[0 x c]]
			4 [[x 0 c]]
			5 [[c 0 x]]
		]
	] color
	color: make tuple! collect [foreach value values-of color [keep round m + value * 255]]
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
	do bind switch type [
		rgb [
			[
				rgb: value
				web: to-hex/size value 6
				hsl: to-hsl value
				hsv: to-hsv value
			]
		]
		web [
			[
				rgb: to tuple! value
				web: value
				hsl: to-hsl rgb
				hsv: to-hsv rgb
			]
		]
		hsl [
			[
				rgb: load-hsl value
				web: to-hex/size rgb 6
				hsl: value
				hsv: to-hsv load-hsv value
			]
		]
		hsv [
			[
				rgb: load-hsv value
				web: to-hex/size rgb 6
				hsl: to-hsl load-hsv value
				hsv: value
			]
		]
	] color
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

example-font: make font! [size: 18 color: black]

gui-example: does [
;	box: base 100x100 font example-font
	view [
		field [
			all [
				not error? value: try [load face/text]
				tuple? value
				color: set-color new-color value 'rgb
				main-box/color: value
				main-box/font/color: select apply-color copy/deep color 'hue 180 'rgb
				sat+50-box/color: select apply-color copy/deep color 'saturate 50% 'rgb
				sat-50-box/color: select apply-color copy/deep color 'desaturate 50% 'rgb
				lit+50-box/color: select apply-color copy/deep color 'lighten 50% 'rgb
				lit-50-box/color: select apply-color copy/deep color 'darken 50% 'rgb
				hue60-box/color: select apply-color copy/deep color 'hue 60 'rgb
				hue120-box/color: select apply-color copy/deep color 'hue 120 'rgb
				hue180-box/color: select apply-color copy/deep color 'hue 180 'rgb
				hue240-box/color: select apply-color copy/deep color 'hue 240 'rgb
			]
		]
		return
		main-box: base 100x100 "color" font example-font
		sat+50-box: base 100x100 "sat+50%" font example-font
		sat-50-box: base 100x100 "sat-50%" font example-font
		lit+50-box: base 100x100 "lit+50%" font example-font
		lit-50-box: base 100x100 "lit-50%" font example-font
		return
		hue60-box: base 100x100 "hue+60" font example-font
		hue120-box: base 100x100 "hue+120" font example-font
		hue180-box: base 100x100 "hue+180" font example-font
		hue240-box: base 100x100 "hue+240" font example-font
		
	]
]