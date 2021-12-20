contract C {
	function callMeMaybe(uint a, uint b) external {}

	function abiEncodeSimple(uint x, uint y, uint z) public view {
		require(x == y);
		function (uint, uint) external f = this.callMeMaybe;
		bytes memory b1 = abi.encodeCall(f, (x, z));
		bytes memory b2 = abi.encodeCall(f, (y, z));
		assert(b1.length == b2.length); // should hold

		bytes memory b3 = abi.encodeCall(this.callMeMaybe, (3, z));
		assert(b1.length == b3.length); // should fail
	}
}
// ====
// SMTEngine: all
// SMTIgnoreCex: yes
// ----
// Warning 6328: (410-440): CHC: Assertion violation happens here.
