pragma solidity >=0.5.0 <0.6.0;

contract BlindAuction {
    
    struct Bid {
        bytes32 blindedBid;
        uint deposit;
    }
    
    address payable public beneficiary; 
    uint public biddingEnd;
    uint public revealEnd;
    address public highestBidder;
    uint public highestBid;
    bool public ended;
    
    mapping (address => Bid) bidderToBid;   // mapping bidder to the respective Bid
    mapping (address => uint) bidderToRefund;   // mapping bidder to refund available
    
    modifier afterTime(uint _time) {require(now > _time); _;}   
    modifier beforeTime(uint _time) {require(now < _time); _;}
    
    event AuctionEnded(address highestBidder, uint highestBid);
    
    constructor (address payable _beneficiary, uint _biddingTime, uint _revealTime) public {
        beneficiary = _beneficiary;
        biddingEnd = now + _biddingTime;
        revealEnd = biddingEnd + _revealTime;
    }
    
    // function for user to register their bid into the system
    function registerBid(uint _value, string memory _password) public payable beforeTime(biddingEnd) {
        require(bidderToBid[msg.sender].blindedBid == bytes32(0), "Can place only one bid from an address"); // prevents bidder from placing multiple bids
        _value = _value * 10**18;   // convert unit of _value from ether to wei
        bytes32 blindedBid = keccak256(abi.encodePacked(_value, _password));    // password prevents people from guessing the _value and hash them
        bidderToBid[msg.sender] = Bid({blindedBid: blindedBid, deposit: msg.value});
    }
    
    // function to reveal the status of the bid for the user and keep account of the refund
    function reveal(uint _value, string memory _password) public 
        afterTime(biddingEnd) 
        beforeTime(revealEnd) 
    {
        uint refund;
        _value = _value * 10**18;
        Bid storage myBid = bidderToBid[msg.sender];
        if (myBid.blindedBid == keccak256(abi.encodePacked(_value, _password))) {
            refund += myBid.deposit;
            if(myBid.deposit >= _value && _placeBid(msg.sender, _value)) {
                refund -= _value;
            }
            myBid.blindedBid = bytes32(0);
            msg.sender.transfer(refund);
        }
    }
    
    // place the bid if the bid is highest than highestBid until then
    function _placeBid(address _bidder, uint _value) internal returns (bool) {
        if (_value <= highestBid) {
            return false;
        }
        if (highestBidder != address(0)) {
            bidderToRefund[highestBidder] += highestBid;
        }
        highestBidder = _bidder;
        highestBid = _value;
        return true;
    }
    
    // withdraw refund
    function withdraw() public {
        uint refund = bidderToRefund[msg.sender];
        if (refund > 0) {
            bidderToRefund[msg.sender] = 0;
            msg.sender.transfer(refund);
        }
    }
    
    // end the auction and send the highest bid to the beneficiary
    function auctionEnd() public afterTime(revealEnd) {
        require(!ended);
        emit AuctionEnded(highestBidder, highestBid);
        ended = true;
        beneficiary.transfer(highestBid);
    }
    
}
