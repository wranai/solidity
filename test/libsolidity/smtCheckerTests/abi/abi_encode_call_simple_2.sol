contract C {
	function callMeMaybe(uint a, uint b) external {}

	function abiEncodeSimple(uint x, uint y, uint z) public view {
		require(x == y);
		bytes memory b1 = abi.encodeCall(this.callMeMaybe, (x, z));
		bytes memory b2 = abi.encodeCall(this.callMeMaybe, (y, z));
		assert(b1.length == b2.length); // should hold but fails for now because function pointers like the above do not have a concrete value

		bytes memory b3 = abi.encodeCall(this.callMeMaybe, (3, z));
		assert(b1.length == b3.length); // should fail
	}
}
// ====
// SMTEngine: all
// SMTIgnoreCex: yes
// ----
// Warning 6328: (273-303): CHC: Assertion violation happens here.
// Warning 6328: (473-503): CHC: Assertion violation happens here.
