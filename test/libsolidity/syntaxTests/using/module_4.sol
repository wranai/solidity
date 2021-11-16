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
// ParserError 1308: (B:36-37): The statement 'using *...' is only allowed at file level.
