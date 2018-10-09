pragma solidity ^0.4.25;
//objective = curate solartainer deployments,
//1 MoU = 1 new SolartainerToken contract with capped supply
//1 solartainer = 80MWh p.a. . Lifetime = 10 years
//1 SolartainerToken = 1kWh
//supply = 800000 (kWh) * n solartainer(s)
//create a new InvestorToken crowdsale for a new MoU
//if funding goal is met, mint proportional amount of SolUtilTokens
//else allow donated funds to be reclaimed

//must import SolInvestToken and SolUtilTokenInterface
import "./SafeMath.sol";
// import "./SOLINVESTTOKEN.sol";
// import "./SOLUTILTOKEN.sol";

contract SunProtocol {
    using SafeMath for uint256;

    address public owner;
    uint public rewardPool;
    uint public totalSupplySolUtilTokens;
    uint public totalSupplySolInvestTokens;
    uint public currentCrowdsale;

    // SolInvestToken public investToken;
    // SolUtilToken public utilityToken;

    enum State { Running, Expired, Funded, Archived }

    struct ContributorStruct {
        bool whitelisted;       /**/
        uint256 contributions;  /**/
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
    modifier inWhitelist(address _contributor) {require(crowdsale[currentCrowdsale].whitelist[_contributor].whitelisted == true); _;}

    event WhitelistingLog(address indexed _contributor);
    event RefundLog(address indexed _contributor, uint256 _amount);
    event PurchaseLog(address indexed _contributor, address indexed _beneficiary, uint256 _amount);

    constructor() public {
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

        //deploy tokens
        // investToken = new SolInvestToken();
        // utilityToken = new SolUtilToken();
    }

/*
0x612077696c64204d6f552061707065617273, 100000, 200000, 1546300799000, 20
137667 gas with memory lol
122428 direct to storage
*/
    function newCrowdsale(
            bytes32 _MoU,
            uint _softCap,
            uint _hardCap,
            uint _deadline,
            uint _containerUnits)
        isOwner
        public
        returns(bool success)
    {
        require(crowdsale[currentCrowdsale].currentState == State.Archived, "Current sale must be finished");

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

    function () public payable {
        //accepts deposits and adds to rewardPool
        rewardPool += msg.value;
        _updateStateIfExpired();
    }

    //available only to whitelisted addresses after startBlock
    function buyTokens(address _beneficiary)
        public
        inState(State.Running)
        inWhitelist(_beneficiary)
        payable
        returns(bool success)
    {
        require(_beneficiary != address(0x00));
        //here comes the bonded curve.price increases per 10.000 tokens

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
        require(crowdsale[currentCrowdsale].whitelist[_contributor].contributions > 0x00);

        uint256 amount = crowdsale[currentCrowdsale].whitelist[_contributor].contributions;
        crowdsale[currentCrowdsale].whitelist[_contributor].contributions = 0x00;
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

    //in cases where funds are not payed in ETH to this contract,
    //as owner, whitelist and give tokens to address.
    function whitelistAddrAndBuyTokens(address _contributor, uint256 _weiAmount)
        public
        isOwner
        inState(State.Running)
        returns(bool success)
    {
        require(_contributor != address(0x00));
        uint256 tokenAmount = _calculateTokenAmount(_weiAmount);

        crowdsale[currentCrowdsale].whitelist[_contributor].whitelisted = true;
        crowdsale[currentCrowdsale].weiRaised += _weiAmount;

        // if (!investToken.mint(_contributor, tokenAmount)) {
        //     revert("Minting failed");
        // }
        emit WhitelistingLog(_contributor);
        return true;
    }

    //withdraw Funds only if funded, as owner
    // function withdraw() public isOwner inState(State.Funded) {
    //     // WALLET.transfer(address(this).balance);
    // }

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

    // function emergencyStop()
    //     public
    //     isOwner
    //     inState(State.Running)
    // {
    //     //prevent more contributions and allow refunds
    //     crowdsale[currentCrowdsale].currentState = State.Expired;
    // }

    function archiveCrowdsale() public isOwner {
        // cant do another crowdsale if currentCrowdsale is Expired...
        // require(crowdsale[currentCrowdsale].currentState != State.Running);
        // require(crowdsale[currentCrowdsale].currentState != State.Expired);
        bytes32 temp = crowdsale[currentCrowdsale].MoU;
        delete crowdsale[currentCrowdsale];
        crowdsale[currentCrowdsale].MoU = temp;
        crowdsale[currentCrowdsale].currentState = State.Archived;
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

    function _calculateTokenAmount(uint256 _weiAmount) internal view returns(uint256 tokenAmount) {

    }


}
