function f(uint[] memory x) pure returns (uint) {
    return x[0];
}
function g(uint[] storage x) pure returns (uint) {
    return x[0];
}
function h(uint[] calldata x) pure returns (uint) {
    return x[0];
}
using {f, g, h} for uint[];
// ----
// TypeError 2527: (131-135): Function declared as pure, but this expression (potentially) reads from the environment or state and thus requires "view".
