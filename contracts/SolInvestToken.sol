pragma solidity ^0.4.25;

import "./Ownable.sol";
import "./DividendBearingToken.sol";
import "./BancorFormula.sol";

/**
* @title Bonding Curve
* @dev Bonding curve contract based on Bacor formula
* inspired by bancor protocol and simondlr and relevant community
* https://github.com/bancorprotocol/contracts
* https://github.com/ConsenSys/curationmarkets/blob/master/CurationMarkets.sol
* https://github.com/relevant-community/bonding-curve
*/

contract SolInvestToken is DividendBearingToken, BancorFormula, Ownable {
    event LogMint(uint256 amountMinted, uint256 totalCost);
    event LogWithdraw(uint256 amountWithdrawn, uint256 reward);
    event LogBondingCurve(string logString, uint256 value);

    // control minting and trading times
    enum State {CrowdSale, Trading}
    State public state;
    modifier inState(State _state) {require(state == _state); _;}

    /**
    * @dev Available balance of reserve token in contract
    */
    uint256 public poolBalance;

    /**
    * @dev reserve ratio, represented in ppm, 1-1000000
    * 1/3 corresponds to y= multiple * x^2
    * 1/2 corresponds to y= multiple * x
    * 2/3 corresponds to y= multiple * x^1/2
    * multiple will depends on contract initialization,
    * specificallytotalAmount and poolBalance parameters
    * we might want to add an 'initialize' function that will allow
    * the owner to send ether to the contract and mint a given amount of tokens
    */
    uint32 public reserveRatio;

    constructor(uint8 _multiple) public {
        require(_multiple > 0 && _multiple < 4);
        // same as 10 eth
        totalSupply_ = 10 * 1e18; // 10000000000000000000
        // one coin costs .00001 ETH with _multiple = 1
        poolBalance = 1 * 1e14;   // 100000000000000
        // 3 = 333333ppm, 2 = 500000ppm, 1 = 1000000ppm
        reserveRatio = uint32(1000000 / _multiple);
    }

    /**
    * @dev default function
    * gas ~ 91645
    */
    function() public payable {
        buy();
    }

    /**
    * @dev Buy tokens
    * gas ~ 77825
    * TODO implement maxAmount that helps prevent miner front-running
    * me : token only buyable
    */
    function buy()
        public
        payable
        onlyOwner
        inState(State.CrowdSale)
        returns(bool)
    {
        require(msg.value > 0x00);

        uint256 tokensToMint = calculatePurchaseReturn(
            totalSupply_,
            poolBalance,
            reserveRatio,
            msg.value
        );

        totalSupply_ = totalSupply_.add(tokensToMint);
        balances[msg.sender] = balances[msg.sender].add(tokensToMint);
        poolBalance = poolBalance.add(msg.value);

        emit LogMint(tokensToMint, msg.value);
        return true;
    }

    /**
    * @dev Sell tokens
    * gas ~ 86936
    * @param sellAmount Amount of tokens to withdraw
    * TODO implement maxAmount that helps prevent miner front-running
    */
    function sell(uint256 sellAmount) public inState(State.Trading) returns(bool) {
        require(sellAmount > 0 && balances[msg.sender] >= sellAmount);

        uint256 ethAmount = calculateSaleReturn(
            totalSupply_,
            poolBalance,
            reserveRatio,
            sellAmount
        );

        poolBalance = poolBalance.sub(ethAmount);
        balances[msg.sender] = balances[msg.sender].sub(sellAmount);
        totalSupply_ = totalSupply_.sub(sellAmount);
        msg.sender.transfer(ethAmount);

        emit LogWithdraw(sellAmount, ethAmount);
        return true;
    }

    /*
    Getters for the prices formulas
    1 ETH = 100000000000000000000000
    1 SIT = .00001000000000000000000 ETH
    */
    function getTokensForWei(
            uint256 _wei,
            uint256 _totalSupply,
            uint256 _poolBalance,
            uint32 _reserveRatio)
        external
        view
        returns(uint256 tokenAmount)
    {
        tokenAmount = calculatePurchaseReturn(
            _totalSupply,
            _poolBalance,
            _reserveRatio,
            _wei
        );
    }

    function getWeiforTokens(
            uint256 _tokens,
            uint256 _totalSupply,
            uint256 _poolBalance,
            uint32 _reserveRatio)
        external
        view
        returns(uint256 weiAmount)
    {
        weiAmount = calculateSaleReturn(
            _totalSupply,
            _poolBalance,
            _reserveRatio,
            _tokens
        );
    }
}
