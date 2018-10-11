pragma solidity ^0.4.25;
pragma experimental ABIEncoderV2;

import "./SafeMath.sol";
import "./SolInvestToken.sol";


contract SunProtocol {
    using SafeMath for uint256;

    address public owner;
    uint public rewardPool;
    uint public totalSupplySolUtilTokens;
    uint public totalSupplySolInvestTokens;
    uint public currentCrowdsale;

    SolInvestToken public investToken;

    enum State { Running, Expired, Funded, Archived }

    struct ContributorStruct {
        bool whitelisted;       /**/
        uint contribution;      /**/
        uint tokensOwned;       /**/
    }

    struct CrowdsaleStruct {
        bytes32 mOfU;
        uint softCap;           /**/
        uint hardCap;           /**/
        uint deadline;          /**/
        uint containerUnits;    /**/
        uint weiRaised;         /**/
        uint mSutMinted;        /**/
        State currentState;     /**/
        mapping(address => ContributorStruct) whitelist;
    }

    mapping(uint => CrowdsaleStruct) public crowdsale;

    modifier isOwner() {require(msg.sender == owner); _;}
    modifier inState(State _state) {require(crowdsale[currentCrowdsale].currentState == _state); _;}
    modifier inWhitelist(address _contributor) {
        require(crowdsale[currentCrowdsale].whitelist[_contributor].whitelisted == true);
        _;
    }

    event WhitelistingLog(address indexed _contributor);
    event RefundLog(address indexed _contributor, uint256 _amount);
    event PurchaseLog(address indexed _contributor, address indexed _beneficiary, uint256 _amount);

    constructor(address _sitAddr) public {
        //create the initial crowdsale
        crowdsale[0] = CrowdsaleStruct({
            mOfU: "Country abc; 50 solartainers",
            softCap: 10 ** 23,           /* 10.000 ether */
            hardCap: 5 * 10 ** 23,           /* 50.000 ether */
            deadline: 1546300799000,    /* Monday, December 31, 2018 11:59:59 PM */
            containerUnits: 50,
            weiRaised: 0x00,
            mSutMinted: 0x00,
            currentState: State.Running
        });

        //set owner
        owner = msg.sender;

        //instantiate token
        investToken = SolInvestToken(_sitAddr);
    }

    function () public payable {
        //accepts deposits and adds to rewardPool
        rewardPool += msg.value;
        _updateStateIfExpired();
    }

    function getWhitelistDetailsFor(address _beneficiary)
        public
        view
        returns(ContributorStruct) 
    {
        return crowdsale[currentCrowdsale].whitelist[_beneficiary];
    }

    function newCrowdsale(
            bytes32 _mOfU,
            uint _softCap,
            uint _hardCap,
            uint _deadline,
            uint _containerUnits)
        public
        isOwner
        returns(bool success)
    {
        require(crowdsale[currentCrowdsale].currentState == State.Archived,
            "Current sale must be finished"
        );

        crowdsale[currentCrowdsale] = CrowdsaleStruct({
            mOfU: _mOfU,
            softCap: _softCap * 1 ether,
            hardCap: _hardCap * 1 ether,
            deadline: _deadline,
            containerUnits: _containerUnits,
            weiRaised: 0,
            mSutMinted: 0,
            currentState: State.Running
        });

        currentCrowdsale++;

        return true;
    }

    //available only to whitelisted addresses when running
    //tokens are minted and added to balanceOf(address(this))
    //disbursement to contributer addrs is done later
    function buyTokens(address _beneficiary)
        public
        inState(State.Running)
        inWhitelist(_beneficiary)
        payable
        returns(bool success)
    {
        require(_beneficiary != address(0x00));

        crowdsale[currentCrowdsale].whitelist[_beneficiary].contribution = msg.value;
        crowdsale[currentCrowdsale].whitelist[_beneficiary].tokensOwned = _getTokenAmount(msg.value);

        if (!investToken.buy.value(msg.value)()) {
            revert("Token purchase failed");
        }

        emit PurchaseLog(msg.sender, _beneficiary, msg.value);
        return true;
    }

    //available to contributers after deadline and only if unfunded
    //if contributer used a different address as _beneficiary, only this address can claim refund
    function refund(address _contributor)
        public
        inState(State.Expired)
        returns(bool success)
    {
        require(_contributor != address(0x00));
        require(crowdsale[currentCrowdsale].whitelist[_contributor].contribution > 0x00);

        uint256 amount = crowdsale[currentCrowdsale].whitelist[_contributor].contribution;
        crowdsale[currentCrowdsale].whitelist[_contributor].contribution = 0x00;
        crowdsale[currentCrowdsale].whitelist[_contributor].tokensOwned = 0x00;
        _contributor.transfer(amount);

        emit RefundLog(_contributor, amount);
        return true;
    }

    //as owner, whitelist individual address
    function whitelistAddr(address _contributor)
        public
        isOwner
        returns(bool success)
    {
        require(_contributor != address(0x00));

        crowdsale[currentCrowdsale].whitelist[_contributor].whitelisted = true;

        emit WhitelistingLog(_contributor);
        return true;
    }

    // withdraw Funds only if funded, as owner
    function withdraw() public isOwner inState(State.Funded) {
        owner.transfer(address(this).balance);
    }

    function delistAddress(address _contributor)
        public
        isOwner
        inState(State.Running)
        returns (bool)
    {
        require(_contributor != address(0x00));
        require(crowdsale[currentCrowdsale].whitelist[_contributor].whitelisted);

        crowdsale[currentCrowdsale].whitelist[_contributor].whitelisted = false;
        return true;
    }

    function _updateStateIfExpired() internal {
        if ((block.timestamp >= crowdsale[currentCrowdsale].deadline &&
                crowdsale[currentCrowdsale].currentState == State.Running)
            || (block.timestamp >= crowdsale[currentCrowdsale].deadline &&
                crowdsale[currentCrowdsale].weiRaised < crowdsale[currentCrowdsale].softCap))
        {
            crowdsale[currentCrowdsale].currentState = State.Expired;
        }
    }

    function _getTokenAmount(uint _wei) internal view returns(uint tokenAmt) {
        tokenAmt = investToken.getTokensForWei(
                        _wei,
                        investToken.totalSupply_(),
                        investToken.poolBalance(),
                        investToken.reserveRatio()
            );
    }
}
