pragma solidity ^0.4.25;

import "./SafeMath.sol";
import "./ERC223.sol";

//token is burnable, ownable, mintable
contract SolUtilToken is ERC223 {
    using SafeMath for uint256;

    string constant public TOKEN_NAME = "SolUtilToken";
    string constant public TOKEN_SYMBOL = "SUT";
    uint8 constant public TOKEN_DECIMALS = 18; // 1 SUT = 1000000000000000000 mSuts //accounting done in mSuts
    // address constant public TOKEN_OWNER = //Token Owner

    function() public {

    }

    constructor() public {
        owner = msg.sender;
    }

    // function name() pure external returns(string) {
    //     return TOKEN_NAME;
    // }

    // function symbol() pure external returns(string) {
    //     return TOKEN_SYMBOL;
    // }

    // function decimals() pure external returns(uint8) {
    //     return uint8(TOKEN_DECIMALS);
    // }

    function balanceOf(address _who) public view returns(uint256) {
        return balances[_who];
    }

    function transfer(address _to, uint _value) public {
        require(_to != address(0x00));
        require(balances[msg.sender] >= _value);

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);

        bytes memory data;
        emit Transfer(msg.sender, _to, _value, data);
    }

    function transfer(address _to, uint _value, bytes _data) public {
        require(_to != address(0x00));
        require(balances[msg.sender] >= _value);

        uint codeLength;
        // all contracts have size > 0, however it's possible to bypass this check with
        // a specially crafted contract. in our case we want to check the msg.sender is
        // either a POA or a contract compliant with the ERC223ReceivingContractInterface
        assembly {
            codeLength := extcodesize(_to)
        }

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);

        if(codeLength > 0x00) {
            ERC223ReceivingContractInterface receiver = ERC223ReceivingContractInterface(_to);
            receiver.tokenFallback(msg.sender, _value, _data);
        }

        emit Transfer(msg.sender, _to, _value, _data);
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns(bool) {
        require(_from != address(0x00));
        require(_to != address(0x00));
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);

        bytes memory data;
        emit Transfer(_from, _to, _value, data);

        return true;
    }

    function approve(address _spender, uint256 _value) public returns(bool) {
        require(_value <= balances[msg.sender]);

        allowed[msg.sender][_spender] = _value;

        emit Approval(msg.sender, _spender, _value);

        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256) {
        require(_owner != address(0x00));
        require(_spender != address(0x00));

        return allowed[_owner][_spender];
    }

    function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
        require(_spender != address(0x00));
        require(_addedValue <= balances[msg.sender]);

        allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);

        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);

        return true;
    }

    function decreaseApproval(address _spender, uint _subtractedValue)
        public
        returns (bool)
    {
        require(_spender != address(0x00));

        uint oldValue = allowed[msg.sender][_spender];

        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0x00;
        } else {
            allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }

        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);

        return true;
    }

    function mint(address _to, uint256 _amount)
        public
        onlyOwner
        canMint
        returns(bool)
    {
        require(_to != address(0x00));

        totalSupply = totalSupply.add(_amount);
        balances[_to] = balances[_to].add(_amount);

        bytes memory data;
        emit Mint(_to, _amount);
        emit Transfer(address(0x00), _to, _amount, data);
        return true;
    }

    function finishMinting()
        public
        onlyOwner
        canMint
        returns (bool)
    {
        mintingFinished = true;

        emit MintFinished();
        return true;
    }

    function burn(uint256 _value) public {
        require(_value > 0x00);
        require(_value <= balances[msg.sender]);

        balances[msg.sender] = balances[msg.sender].sub(_value);
        totalSupply = totalSupply.sub(_value);

        emit Burn(msg.sender, _value);
    }

    //change owner addr to crowdsale contract to enable minting
    //if successful the crowdsale contract will reset owner to TOKEN_OWNER
    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != address(0x00));

        owner = _newOwner;

        emit OwnershipTransferred(msg.sender, owner);
    }

}
