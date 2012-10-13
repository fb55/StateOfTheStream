__EXTREMELY EXPERIMENTAL__

State machines are a thing of beauty, as are streams. Let's see how we can unite both worlds!

Basic structure of accepted JSON:

```js
{
	<state>: {
		"*": "next_state" || <num>,
		ELSE: //if nothing was matched
		EOF: //end of file
		BOF: //beginning of file
			{
				nextState: "next_state" || {
					name: "next_state"
					--or--
					restore: "name" //restore state
				},
				saveAs: "name", //save current state

				emit: "event", //this.emit("event", <index>)
				cb: "name", //this.cbs[name](index)

				index: {
					saveAs: "name" || <num>
					increase: false || <num> //defaults to 1
					restore: "name" || <num>
				}
			}
	} ||
	<state>: [
		{ char: ["a", "b"], nextState: "next_state" },
		{ char: "a", nextState: <num> },
	]
}
```