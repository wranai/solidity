// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

contract MyContract
{
    function f1() public pure
    {
        uint unused1; // [Warning 2072] Unused local variable.
        uint unused2;
    }

    function f2() public pure returns (uint)
    {
        // return; // [Error 6777] Return arguments required.
        // uint typeError = 3.14; // [Error 4486] Type error. (and unused and after return stmt)
    }
}
