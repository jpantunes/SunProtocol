pragma solidity ^0.4.25;

import "./ERC20.sol";


contract DividendBearingToken is ERC20 {

    uint256 public totalDividends;

    struct Account {
        uint256 balance;
        uint256 lastDividends;
    }

    mapping(address => Account) public accounts;

    function () public payable {
        totalDividends = totalDividends.add(msg.value);
    }

    function dividendBalanceOf(address account) public view returns (uint256) {
        uint256 newDividends = totalDividends.sub(accounts[account].lastDividends);
        uint256 product = accounts[account].balance.mul(newDividends);
        return product.div(totalSupply_);
    }

    function claimDividend() public {
        uint256 owing = dividendBalanceOf(msg.sender);
        if (owing > 0) {
            accounts[msg.sender].lastDividends = totalDividends;
            msg.sender.transfer(owing);
        }
    }

    function _transfer(address _from, address _to, uint256 _value) internal {
        require(_to != address(0));
        require(_value <= accounts[_from].balance);
        require(accounts[_to].balance + _value >= accounts[_to].balance);

        uint256 fromOwing = dividendBalanceOf(_from);
        uint256 toOwing = dividendBalanceOf(_to);
        require(fromOwing <= 0 && toOwing <= 0);

        accounts[_from].balance = accounts[_from].balance.sub(_value);
        accounts[_to].balance = accounts[_to].balance.add(_value);
        accounts[_to].lastDividends = accounts[_from].lastDividends;

        emit Transfer(_from, _to, _value);
    }

}
