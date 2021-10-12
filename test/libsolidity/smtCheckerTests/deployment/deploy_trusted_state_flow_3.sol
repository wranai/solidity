contract D {
	uint x;
	function s(uint _x) public { x = _x; }
	function f() public view returns (uint) { return x; }
}

contract C {
	D d;
	constructor() {
		d = new D();
	}
	function g() public view {
		assert(d.f() == 0); // should fail
	}
}
// ====
// SMTContract: C
// SMTEngine: all
// SMTExtCalls: trusted
// ----
// Info 1180: Contract invariant(s) for :C:\n((:var 1).storage.storage_D_22[d].x_3_D_22 <= 0)\nReentrancy property(ies) for :D:\n((<errorCode> = 0) && ((:var 1) = (:var 3)) && (x' = x))\n<errorCode> = 0 -> no errors\n<errorCode> = 1 -> Assertion failed at assert(d.f() == 0)\n
