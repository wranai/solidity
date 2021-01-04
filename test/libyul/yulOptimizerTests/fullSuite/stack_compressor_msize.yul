{
	let a

	function gcd(_a, _b) -> out
	{
		// GCD algorithm. in order to test underlying stack compressor this function must not be inlined.
		switch _b
		case 0 { out := _a }
		default { out := gcd(_b, mod(_a, _b)) }
	}

	function f() -> out
	{
		out := gcd(10, 15)
	}

	function foo_singlereturn_0() -> out
	{
		mstore(lt(or(gt(1,or(or(gt(or(or(or(1,gt(or(gt(or(or(keccak256(f(),or(gt(not(f()),1),1)),1),not(1)),f()),1),f())),lt(or(1,sub(f(),1)),1)),f()),1),1),gt(not(f()),1))),1),1),1)
		sstore(not(f()),1)
	}

	function foo_singlereturn_1(in_1, in_2) -> out
	{
		extcodecopy(1,msize(),1,1)
	}

	a := foo_singlereturn_0()
	sstore(0,0)
	sstore(2,1)

	a := foo_singlereturn_1(calldataload(0),calldataload(3))
	sstore(0,0)
	sstore(3,1)
}
// ----
// step: fullSuite
//
// {
//     {
//         let _1 := 15
//         let _2 := 10
//         pop(gcd(_2, _1))
//         pop(gcd(_2, _1))
//         pop(gcd(_2, _1))
//         pop(gcd(_2, _1))
//         pop(gcd(_2, _1))
//         let _3 := 1
//         pop(keccak256(gcd(_2, _1), or(gt(not(gcd(_2, _1)), _3), _3)))
//         mstore(0, _3)
//         sstore(not(gcd(_2, _1)), _3)
//         sstore(0, 0)
//         sstore(2, _3)
//         extcodecopy(_3, msize(), _3, _3)
//         sstore(0, 0)
//         sstore(3, _3)
//     }
//     function gcd(_a, _b) -> out
//     {
//         switch _b
//         case 0 { out := _a }
//         default { out := gcd(_b, mod(_a, _b)) }
//     }
// }
