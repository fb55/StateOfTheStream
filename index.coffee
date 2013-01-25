streamStart = require("fs").readFileSync(__dirname + "/stream-start.js").toString "utf8"

class Compiler
	constructor: (@states) ->
		@names = {__proto__:null}
		@parsedRules = {}
		@currentlyRendered = {}

		#collect all names & ensure that @states is an array
		unless Array.isArray @states
			i = 0
			@states = for name, state of @states
				@names[name] = i++
				state
		else for state, i in @states
			if state.name?
				throw Error("state #{state.name} exists already") if state.name of @names
				@names[state.name] = i
			throw Error("state #{i} exists already") if i of @names and @names[i] isnt i
			@names[i] = i

		throw Error("no start state available (needs to be named 0)") unless 0 of @names

		@parse @names[0] #parse the initial state

	parse: (name) ->
		state = @states[name]

		return @parsedRules[name] if name of @parsedRules

		#ensure state is an array
		unless Array.isArray state
			state = for char, rule of state
				if typeof rule is "object"
					if rule.char?
						if Array.isArray rule.char
							rule.char.push(char) unless char in rule.char
						else if rule.char isnt char
							rule.char = [rule.char, char]
					else
						rule.char = [char]
					rule
				else {
					nextState: rule
					char: [char]
				}

		elseRule = null
		eofRule = null

		rules = (for rule in state
			chars = if Array.isArray(rule.char) then rule.char else [rule.char]
			allChars = {}
			chars = 
				(for char in chars
					if char of allChars
						throw Error "#{if typeof char is "string" then char else String.fromCharCode char} exists twice"
					allChars[char] = true
					if typeof char is "string"
						if char.length isnt 1
							#check for special tokens "ELSE", "EOF" & "BOF"
							if char is "ELSE"
								elseRule = rule
								continue
							else if char is "EOF"
								eofRule = rule
								continue
							else if char is "BOF"
								"(this._index===0&&this._removedChars===0)"
							else throw Error "chars need to have a length of 1"
						else
							char = char.charCodeAt 0
							throw Error("#{String.fromCharCode char} exists twice") if char of allChars
							allChars[char] = true
							"char===#{char}"
					else unless typeof typeof char is "number"
						throw Error "chars need to be either strings or numbers"
					else
						"char===#{char}"
				)

			if chars.length > 0 
				"""
				if(#{chars.join "||"}){
					#{@renderAction rule, name}
				}
				"""
			else
				continue
		)

		@parsedRules[name] = 
			"""
			if(this._data.length <= this._index){
				if(this._ended){
					#{
						if eofRule then @renderAction elseRule, name
						else "this._cbs.onerror(Error('undepected EOF'))"
					}
				} else {
					this._state = '#{name}';
					return;
				}
			} else {
				var char = this._data[this._index];
			"""

		if elseRule
			rules.push "{#{@renderAction elseRule, name}}"
		else
			rules.push "this._cbs.onerror(Error('Unmatched char ' + String.fromCharCode(c)));"
		
		@parsedRules[name] += rules.join(" else ") + "}"

	renderAction: (rule, state) ->
		unless rule? then console.log state
		result = ""

		if "cb" of rule
			result += "this._cbs['#{rule.cb}'](this._index);"

		if typeof rule.index is "object"
			if rule.index.saveAs?
				result += "this.indices['#{rule.index.saveAs}'] = this._index;"
			if rule.index.restore?
				result += "this._index = this.indices['#{rule.index.restore}'];"
			else if rule.index.increase or !(increase of rule.index)
				result += "this._index += #{rule.index.increase or 1};"
		else
			result += "this._index++;"

		if typeof rule.nextState is "object" and "restore" of rule.nextState
			result += "this[this._stateCache['#{rule.nextState.restore}']]();"
		else
			nextState = if typeof rule.nextState isnt "object" then rule.nextState else rule.nextState.name

			if nextState of @names
				nextState = @names[nextState]
			else
				throw Error "couldn't resolve state '#{nextState}'"

			#avoid infinite loops
			if @currentlyRendered[nextState]
				result += "this['#{nextState}']();"
			else
				prevState = @currentlyRendered[state] or false
				@currentlyRendered[state] = true
				result += "this['#{nextState}']();"
				@parse nextState #TODO inline the next state
				@currentlyRendered[state] = prevState
		result

	toString: () ->
			 streamStart + @parsedRules
			 	.map((state, data)->"StateMachine.prototype['#{state}'] = function(){#{data}};")
			 	.join "\n"

module.exports = Compiler