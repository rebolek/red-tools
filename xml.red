Red [
	Title:          "XML"
	Description:    "Parser for XML format. Transforms XML data into red block"
	Author:         ["Iosif Haidu" "Boleslav Březovský"]
	Rights:         "Copyright (c) 2016-2020 Iosif Haidu. All rights reserved."
	License: {
		Redistribution and use in source and binary forms, with or without modification,
		are permitted provided that the following conditions are met:

			* Redistributions of source code must retain the above copyright notice,
				this list of conditions and the following disclaimer.
			* Redistributions in binary form must reproduce the above copyright notice,
				this list of conditions and the following disclaimer in the documentation
				and/or other materials provided with the distribution.

		THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
		ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
		WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
		DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
		FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
		DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
		SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
		CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
		OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
		OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
	}
]

xml: context [
	name-chars: charset [#"a" - #"z" #"A" - #"Z"  #"0" - #"9" #"-" #":"]
	ws:         charset reduce [space tab cr lf]
	attributes: [
		any ws some name-chars change ["="] space
		2 thru #"^"" any ws 
	]
	comments:   [change [any ws "<!--" thru "-->"] ""]    
	nodes:      [
		any [
			change [any ws "<?xml"] "[" any attributes change ["?>"] "]"
		|	comments
		|	change [any ws "<!"] "[" to ">" change [">"] "]"
		] 
		insert "[" any [ 
			[
				change [any ws #"<" s: some name-chars e: any ws] (copy/part s e) (value: none)
					insert "[ " any attributes 
					[change ["/>"] "][ ] " | change [">"] " ][ " (value: true)]
				| comments
				| change ["</" thru ">"] "]" 
				| change [cr | lf] ""
				| if (value) insert #"^"" to "</" insert #"^"" (value: none)
				| skip
			]
		] insert "]"
   ]

	set 'old-xml function [
		"Converts XML data in string or block format"
		/to-block   "Converts an XML string into block"
		xml-str     [ string! ] "XML in string format"
		/to-string  "Converts an XML block into string"
		xml-block   [ block! ] "XML in block format"
	][
		case [
			to-block [
				parse s: copy xml-str nodes
				load s
			]
			to-string [
				;-- TBD
			] 
		]
	]  

	decode: function [
		data
	] [
		parse s: copy data nodes
		load s
	]

; === encoder part

	dbl-quot: #"^""
	output: make string! 10000

	enquote: function [value] [rejoin [dbl-quot value dbl-quot]]

	make-atts: function [
		data
	] [
		copy collect/into [
			foreach [key value] data [
				keep rejoin [key #"=" enquote value space]
			]
		] clear ""
	]

	make-tag: function [
		name
		/with
			atts
		/close
		/empty
	] [
		atts: either with [rejoin [space make-atts atts]] [""]
		rejoin trim reduce [#"<" if close [#"/"] form name atts if empty [" /"] #">"] 
	]

	process-tag: function [
		data
	] [
		output: make string! 1000
	;	unless length? data [print "PROBLEM"]
		either 3 = length? data [
			; tag
			either empty? data/3 [
				; empty tag
				repend output [#"<" form data/1 space make-atts data/2 "/>"] 
			] [
				; tag pair
				repend output [#"<" form data/1 space make-atts data/2 ">"] 
				until [
					repend output process-tag take/part data/3 3
					remove ind
					empty? data/3
				]
				repend output ["</" form data/1 ">"]
			]
		] [
			; content
			output: data/1
		]
		output
	]

	encode: function [
		data
	] [
		clear output
		header: take data: copy/deep data
		repend output ["<?xml " make-atts header "?>"]
		data: data/1
		until [
			repend output process-tag take/part data 3
			empty? data
		]
		output
	]
]
