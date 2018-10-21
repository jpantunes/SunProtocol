pragma solidity ^0.4.25;
pragma experimental ABIEncoderV2;

//objective = curate solartainer deployments,
//1 MoU = 1 new SolartainerToken contract with capped supply
//1 solartainer = 80MWh p.a. . Lifetime = 10 years
//1 SolartainerToken = 1kWh
//supply = 800000 (kWh) * n solartainer(s)
//create a new InvestorToken crowdsale for a new MoU
//if funding goal is met, mint proportional amount of SolUtilTokens
//else allow donated funds to be reclaimed


import "./SafeMath.sol";
import "./SOLINVESTTOKEN.sol";

contract SunProtocol {
    using SafeMath for uint256;

    address public owner;
    uint public rewardPool;
    uint public totalSupplySolUtilTokens;
    uint public totalSupplySolInvestTokens;
    uint public currentCrowdsale;

    SolInvestToken public investToken;

    enum State { Running, Expired, Funded }

    struct ContributorStruct {
        bool whitelisted;       /**/
        uint contribution;      /**/
        uint tokensOwned;       /**/
    }

    struct CrowdsaleStruct {
        bytes32 MoU;
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
    event BlacklistingLog(address indexed _contributor);
    event RefundLog(address indexed _contributor, uint256 _amount);
    event PurchaseLog(address indexed _contributor, address indexed _beneficiary, uint256 _amount);

    constructor(address _sitAddr) public {
        //create the initial crowdsale
        crowdsale[0] = CrowdsaleStruct({
            MoU: "Country abc; 50 solartainers",
            softCap: 10 **23,           /* 10.000 ether */
            hardCap: 5*10 **23,           /* 50.000 ether */
            deadline: 1546300799000,    /* Monday, December 31, 2018 11:59:59 PM */
            containerUnits: 50,
            weiRaised: 0,
            mSutMinted: 0,
            currentState: State.Running
        });

        //set owner
        owner = msg.sender;

        //instantiate tokens
        investToken = SolInvestToken(_sitAddr);
        //deploy tokens
        // investToken = new SolInvestToken();
        // utilityToken = new SolUtilToken();
    }

    function () public payable {
        //accepts deposits and adds to rewardPool
        rewardPool = rewardPool.add(msg.value);
        _updateState();
    }

    function getWhitelistDetailsFor(address _beneficiary) public view returns (ContributorStruct) {
        return crowdsale[currentCrowdsale].whitelist[_beneficiary];
    }

/*
0x612077696c64204d6f552061707065617273, 100000, 200000, 1546300799000, 20
*/
    function newCrowdsale(
            bytes32 _MoU,
            uint _softCap,
            uint _hardCap,
            uint _deadline,
            uint _containerUnits)
        public
        isOwner
        returns(bool success)
    {
        require(crowdsale[currentCrowdsale].currentState != State.Running, "Current sale must be finished");

        crowdsale[currentCrowdsale] = CrowdsaleStruct({
            MoU: _MoU,
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

    //available only to whitelisted addresses after startBlock
    //tokens are minted and added to balanceOf(address(this))
    //dispensation of tokens to contributer addr is done later
    function buyTokens(address _beneficiary)
        public
        inState(State.Running) // allows 1 buy order above hardCap if status = State.Running || msg.value+ weiRaised > hardCap
        inWhitelist(_beneficiary) // non-whitelisted addresses can buy tokens for a whitelisted address
        payable
        returns(bool success)
    {
        // msg.sender must be whitelisted but _beneficiary addr is any except 0x00
        // require(crowdsale[currentCrowdsale].whitelist[msg.sender].whitelisted == true);
        // require(_beneficiary != 0x00);

        // to prevent a single wei above hardcap
        // _updateState();
        // assert(crowdsale[currentCrowdsale].currentState == State.Running);

        crowdsale[currentCrowdsale].whitelist[_beneficiary].contribution = msg.value;
        crowdsale[currentCrowdsale].whitelist[_beneficiary].tokensOwned = _getTokenAmount(msg.value);
        crowdsale[currentCrowdsale].weiRaised = crowdsale[currentCrowdsale].weiRaised.add(msg.value);

        emit PurchaseLog(msg.sender, _beneficiary, msg.value);

        return true;
    }

    //available to contributers after deadline and only if unfunded
    //if contributer used a different address as _beneficiary, only this address can claim refund
    function refund(address _contributor)
        public
        inState(State.Expired)
        inWhitelist(_contributor) // non-whitelisted addresses can ask refund for a whitelisted address
        returns(bool success)
    {
        require(crowdsale[currentCrowdsale].whitelist[_contributor].contribution > 0x00);

        uint256 amount = crowdsale[currentCrowdsale].whitelist[_contributor].contribution;
        // delete crowdsale[currentCrowdsale].whitelist[_contributor]; //keeping the whitelisted
        crowdsale[currentCrowdsale].whitelist[_contributor].contribution = 0x00;
        crowdsale[currentCrowdsale].whitelist[_contributor].tokensOwned = 0x00;
        crowdsale[currentCrowdsale].weiRaised = crowdsale[currentCrowdsale].weiRaised.sub(amount);
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

    //as owner, blacklist individual address
    function delistAddress(address _contributor)
        public
        isOwner
        inState(State.Running)
        returns (bool)
    {
        require(_contributor != address(0x00));
        require(crowdsale[currentCrowdsale].whitelist[_contributor].whitelisted);

        crowdsale[currentCrowdsale].whitelist[_contributor].whitelisted = false;
        //what if contribution > 0?
        // crowdsale[currentCrowdsale].whitelist[_contributor].tokensOwned = 0x00;
        // crowdsale[currentCrowdsale].whitelist[_contributor].contribution = 0x00;

        emit BlacklistingLog(_contributor);
        return true;
    }

    // withdraw Funds only if funded, as owner
    function withdraw() public isOwner inState(State.Funded) {
        owner.transfer(address(this).balance);
    }

    // as owner prevent more contributions and allow refunds
    function emergencyStop() public isOwner inState(State.Running) {
        crowdsale[currentCrowdsale].currentState = State.Expired;
    }

    // as owner delete finished crowdsale
    // all relevant data is available in logs
    function archiveCrowdsale(uint _crowdsaleNr) public isOwner {
        State crowdsaleState = crowdsale[_crowdsaleNr].currentState;
        uint deadline = crowdsale[_crowdsaleNr].deadline;
        uint refundAmt = crowdsale[_crowdsaleNr].weiRaised;

        if ((crowdsaleState == State.Funded  && block.timestamp > deadline.add(60 days))
            ||
            (crowdsaleState == State.Expired && refundAmt == 0x00))
        {
            delete crowdsale[_crowdsaleNr];
        }
    }

    // updates currentState of currentCrowdsale
    function _updateState() internal {
        State crowdsaleState = crowdsale[currentCrowdsale].currentState;
        uint deadline = crowdsale[currentCrowdsale].deadline;
        uint weiRaised = crowdsale[currentCrowdsale].weiRaised;
        uint softCap = crowdsale[currentCrowdsale].softCap;
        uint hardCap = crowdsale[currentCrowdsale].hardCap;

        if (block.timestamp >= deadline
                && crowdsaleState == State.Running
                && weiRaised < softCap)
        {
            crowdsale[currentCrowdsale].currentState = State.Expired;
        }
        else if ((block.timestamp >= deadline && weiRaised >= softCap)
                || weiRaised >= hardCap)
        {
            crowdsale[currentCrowdsale].currentState = State.Funded;
        }
    }

    //use getters from investToken
    function _getTokenAmount(uint _wei) internal view returns(uint tokenAmt) {
        tokenAmt = investToken.getTokensForWei(
                        _wei,
                        investToken.totalSupply_(),
                        investToken.poolBalance(),
                        investToken.reserveRatio()
            );
    }
}
