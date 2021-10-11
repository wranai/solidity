==== Source: A ====
function inc(uint x) pure returns (uint) {
    return x + 1;
}

==== Source: B ====
import {inc as f} from "A";
import "A";
using * for uint;
contract C {
	function f(uint x) public returns (uint) {
        return x.f() + x.inc();
    }
}
// ====
// compileViaYul: also
// ----
// f(uint256): 5 -> 12
// f(uint256): 10 -> 0x16
