require("coffee-script");
var Compiler = require("./");

var syntax = {
	0: {
		"a": {
			nextState: 2,
			cb: "a"
		},
		"b": {
			nextState: 3,
			cb: "b"
		},
		ELSE: {
			nextState: 1,
			cb: "else"
		}
	},
	1: {
		"a": 2,
		"b": 3,
		ELSE: 1
	},
	2: {
		"a": 2,
		"b": 3,
		ELSE: 1
	},
	3: {
		EOF: {
			nextState: 3,
			cb: "end"
		},
		ELSE: 3
	}
};

var result = new Compiler(syntax).toString();