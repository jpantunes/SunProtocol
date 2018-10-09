pragma solidity ^0.4.25;

/**
 * Math operations with safety checks
 */
library SafeMath {
  function mul(uint a, uint b) internal pure returns (uint) {
    uint c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint a, uint b) internal pure returns (uint) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint a, uint b) internal pure returns (uint) {
    assert(b <= a);
    return a - b;
  }

  function add(uint a, uint b) internal pure returns (uint) {
    uint c = a + b;
    assert(c >= a);
    return c;
  }

    function sqrt(uint _x) internal pure returns (uint y) {
        if (_x == 0) {
            return 0;
        } else if (_x <= 3) {
            return 1;
        } else {
            assembly {
                let z := div(add(_x, 0x01), 0x02)
                y := _x
                for { } lt(z, y) { } {     // while(z < y)
                    y := z
                    z := div(add(div(_x, z), z), 0x02)
                }
            }
        }
    }

}
