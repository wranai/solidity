contract State {
	function f(uint _x) public pure returns (uint) {
		assert(_x < 100);
		return _x;
	}
}
contract C {
	State s;
	uint z = s.f(2);

	function f() public view {
		assert(z == 2); // should hold in trusted mode
	}
}
// ====
// SMTContract: C
// SMTEngine: all
// SMTExtCalls: trusted
// ----
// Info 1180: Reentrancy property(ies) for :State:\n((<errorCode> = 0) && ((:var 0) = (:var 1)))\n<errorCode> = 0 -> no errors\n<errorCode> = 2 -> Assertion failed at assert(z == 2)\n
