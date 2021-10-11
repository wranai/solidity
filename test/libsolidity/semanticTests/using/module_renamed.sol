==== Source: A ====
function f(uint x) pure returns (uint) {
    return x + 2;
}
function g(uint x) pure returns (uint) {
    return x + 8;
}

==== Source: B ====
import {f as g, g as f} from "A";

==== Source: C ====
import "B" as M;

using M for uint;

contract C {
	function test(uint x, uint y) public pure returns (uint, uint) {
        return (x.f(), y.g());
    }
}
// ====
// compileViaYul: also
// ----
// test(uint256,uint256): 1, 1 -> 9, 3
