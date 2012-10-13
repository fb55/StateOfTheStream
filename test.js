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
//console.log(result);
var StateMachine = (Function("var module={};"+result + "return module.exports;"))();

var cbs = ["a", "b", "end", "else"].reduce(function(o, e){ o[e] = console.log.bind(null, e); return o; }, {});
var sm = new StateMachine(cbs);
sm.write(new Buffer("caeb"));
sm.end();