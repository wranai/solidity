==== Source: A ====
function id(uint x) pure returns (uint) {
    return x;
}

==== Source: B ====
import "A";

contract C {
    using * for uint;
    function f(uint x) public pure returns (uint) {
        return x.id();
    }
}
// ----
// SyntaxError 1308: (B:30-47): The statement 'using *...' is only allowed at file level.
