contract State {
	C c;
	constructor(C _c) {
		c = _c;
	}
	function f() public returns (uint) {
		c.setOwner(address(0));
		return c.g();
	}
}

contract C {
	address owner;
	uint y;
	State s;

	constructor() {
		owner = msg.sender;
		s = new State(this);
	}

	function setOwner(address _owner) public {
		owner = _owner;
	}

	function f() public {
		address prevOwner = owner;
		uint z = s.f();
		assert(z == y); // should hold
		assert(prevOwner == owner); // should not hold because of reentrancy
	}

	function g() public view returns (uint) {
		return y;
	}
}
// ====
// SMTContract: C
// SMTEngine: chc
// SMTExtCalls: trusted
// ----
// Warning 6328: (429-455): CHC: Assertion violation happens here.
// Info 1180: Contract invariant(s) for :C:\n(((address(this) + ((- 1) * (:var 3).storage.storage_State_35[s].c_4_State_35)) >= 0) && ((address(this) + ((- 1) * (:var 3).storage.storage_State_35[s].c_4_State_35)) <= 0))\nReentrancy property(ies) for :State:\n((<errorCode> = 0) && ((:var 1) = (:var 3)) && (c' = c))\n<errorCode> = 0 -> no errors\n<errorCode> = 1 -> Assertion failed at assert(z == y)\n<errorCode> = 2 -> Assertion failed at assert(prevOwner == owner)\n
