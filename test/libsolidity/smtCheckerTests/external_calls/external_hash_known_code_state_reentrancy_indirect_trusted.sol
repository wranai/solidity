contract Other {
	C c;
	constructor(C _c) {
		c = _c;
	}
	function h() public {
		c.setOwner(address(0));
	}
}

contract State {
	uint x;
	Other o;
	C c;
	constructor(C _c) {
		c = _c;
		o = new Other(_c);
	}
	function f() public returns (uint) {
		o.h();
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
// Warning 6328: (564-590): CHC: Assertion violation happens here.
// Info 1180: Contract invariant(s) for :C:\n(((address(this) + ((- 1) * (:var 3).storage.storage_State_72[s].c_37_State_72)) >= 0) && ((address(this) + ((- 1) * (:var 3).storage.storage_State_72[s].c_37_State_72)) <= 0))\nReentrancy property(ies) for :State:\n((<errorCode> = 0) && ((:var 3) = (:var 7)) && (x' = x) && (o' = o) && (c' = c))\n<errorCode> = 0 -> no errors\n<errorCode> = 1 -> Assertion failed at assert(z == y)\n<errorCode> = 2 -> Assertion failed at assert(prevOwner == owner)\n
