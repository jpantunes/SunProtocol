pragma solidity ^0.4.25;

import "./SafeMath.sol";
/**
 * @title ERC20 mock
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 {
    using SafeMath for uint256;
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowed;
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
        balances[_to] = balances[_to].add(_value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);

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

//interface style
//   function totalSupply() public view returns (uint256);

//   function balanceOf(address _who) public view returns (uint256);

//   function allowance(address _owner, address _spender)
//     public view returns (uint256);

//   function transfer(address _to, uint256 _value) public returns (bool);

//   function approve(address _spender, uint256 _value)
//     public returns (bool);

//   function transferFrom(address _from, address _to, uint256 _value)
//     public returns (bool);
