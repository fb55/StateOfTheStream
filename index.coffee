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
							rule.char.push(char) 
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
				""
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
				#{
					if rules.length > 0
						rules.join(" else ") + "\nelse {" +
							if elseRule then @renderAction elseRule, name
							else "this._cbs.onerror(Error('Unmatched char ' + String.fromCharCode(c)));"
						+ "}"
					else
						if elseRule then @renderAction elseRule, name
						else "" #TODO should an error be thrown?
				}
			}
			"""

	renderAction: (rule, state) ->
		result = ""
		if "saveAs" of rule
			result += "this._stateCache['#{rule.saveAs}'] = '#{state}';"

		if "cb" of rule
			result += "this._cbs['#{rule.cb}'](this._index);"

		if typeof rule.replace is "object"
			result +=
				"""
				//TODO replace
				"""

		if typeof rule.index is "object"
			if rule.index.saveAs?
				result += "this.indices['#{rule.index.saveAs}'] = this._index;"
			if rule.index.restore?
				result += "this._index = this.indices['#{rule.index.restore}'];"
			else if rule.index.increase or !(increase of rule.index)
				result += "this._index += #{rule.index.increase or 1};"
		else
			result += "this._index++;"

		if typeof rule.nextState is "object" and nextState.restore
			result += "this[this._stateCache['#{nextState.restore}']]();"
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
				result += @parse nextState #inline the next state
				@currentlyRendered[state] = prevState
		result

	toString: () ->
		"""
function StateMachine(cbs){
	this._cbs = cbs;
	this._stateCache = {__proto__:null};
	this.indices = {__proto__:null};
	this._data = new Buffer;
	this._index = 0;
	this._removedChars = 0; //chars that were cleaned
	this._state = "0";
	this._ended = false;
}

StateMachine.prototype.write = function(chunk){
	if(this._data.length === 0) this._data = chunk;
	else this._data = Buffer.concat(this._data, chunk);

	this[this._state]();
};

StateMachine.prototype._clean = function(){
	var maxIndex = this._index, key;
	for(key in this.indices){
		if(this.indices[key] < maxIndex){
			maxIndex = this.indices[key];
		}
	}
	if(maxIndex > 0){
		this._data = this._data.slice(maxIndex);
		this._index -= maxIndex;
		for(key in this.indices){
			this.indices[key] -= maxIndex;
		}
		this._removedChars += maxIndex;
	}
};

StateMachine.prototype.end = function(chunk){
	this._ended = true;
	if(chunk) this.write(chunk);
	else this[this._state]();
};

StateMachine.prototype.getData = function(from, to){
	if(typeof to !== "number") to = this._index;
	return this._data.slice(from, to);
};
		""" + (for state, data of @parsedRules
				"StateMachine.prototype['#{state}'] = function(){#{data}};"
			).join("\n") +
		"\nmodule.exports=StateMachine;"

module.exports = Compiler