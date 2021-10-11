function sum(uint[] memory arr) returns (uint result) {
    for(uint i = 0; i < arr.length; i++) {
        result += arr[i];
    }
}
using {sum} for uint[];

contract C {
    function f(uint[] calldata arr) external returns (uint) {
        return arr.sum();
    }
}
// ====
// compileViaYul: also
// ----
// f(uint256[]): 0x20, 3, 1, 2, 8 -> 11
