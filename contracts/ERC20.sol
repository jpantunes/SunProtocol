pragma solidity ^0.4.24;

import "./SafeMath.sol";
/**
 * @title ERC20 mock token
 */
contract ERC20 {

    using SafeMath for uint256;
    mapping(address => uint256) public balances;
    uint256 public totalSupply_;

    constructor() public {
        totalSupply_ = 10000;
    }

    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }

    function balanceOf(address _who) public view returns (uint256) {
        return balances[_who];
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        return true;
    }

  event Transfer(
    address indexed from,
    address indexed to,
    uint256 value
  );

  event Approval(
    address indexed owner,
    address indexed spender,
    uint256 value
  );
}
