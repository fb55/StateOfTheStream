module.exports = StateMachine;

function StateMachine(cbs){
	this._cbs = cbs;
	this._stateCache = {__proto__:null};
	this.indices = {__proto__:null};
	this._data = new Buffer(0);
	this._index = 0;
	this._removedChars = 0; //chars that were cleaned
	this._state = "0";
	this._ended = false;
}

StateMachine.prototype.write = function(chunk){
	if(this._data.length === 0) this._data = chunk;
	else this._data = Buffer.concat([this._data, chunk]);

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