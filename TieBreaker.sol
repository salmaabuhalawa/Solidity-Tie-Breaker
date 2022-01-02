//SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract tieBreaker{
    
    struct blindHand{
        bytes32 blindedHand;
        uint deposit;
        bool commited;
        bool revealed;
    }

    struct revealedHand{
        uint hand;
        address participant;
    }

    mapping (address => blindHand[]) blindedHands;

    address public manager;
    address public firstParticipant;
    address public secondParticipant;
    uint public reward;
    uint public depositValue;
    uint public commitEnd;
    uint public revealEnd;
    bool public ended;
    

    uint notRefunded = 0;
    uint i = 0;
    revealedHand[2] public participantHands;

    event winnerSelected(address winner);
    event tie(address participant1, address participant2);

    event commitmentDoesNotMatch(address participant);
    event schemeNotFollowed(address participant);

    event neitherParticipantfollowed();
    event participantDidNotFollow(address participant);

    modifier onlyBefore(uint _time) {
        require(block.timestamp < _time,"Already Ended.");
        _;
    }
    modifier onlyAfter(uint _time) {
        require(block.timestamp > _time,"Has not begun yet.");
        _;
    }

    constructor (
        uint _deposit, 
        uint _commitEnd, 
        uint _revealEnd, 
        address _firstParticipant, 
        address _secondParticipant) payable 
    
    {   require(msg.sender != _firstParticipant, "Manager cannot be a participant");
        require(msg.sender != _secondParticipant,"Manager cannot be a participant");
        require(_secondParticipant != _firstParticipant,"Must be different participants");
        manager = msg.sender;
        reward = msg.value;
        depositValue = _deposit;
        commitEnd = block.timestamp + _commitEnd;
        revealEnd = commitEnd + _revealEnd;
        firstParticipant = _firstParticipant;
        secondParticipant = _secondParticipant;
        ended = false;
         blindedHands[firstParticipant].push(blindHand({
            blindedHand : 0,
            deposit :0,
            commited : false,
            revealed : false
        }));
         blindedHands[secondParticipant].push(blindHand({
            blindedHand : 0,
            deposit :0,
            commited : false,
            revealed : false
        }));
    }
    
    /// Use these values to correspond to your hand:
    /// Rock = 1 Paper = 2 Scissors = 3
    /// Place a blinded hand with `_blindedhand` = keccak256(hand,
    /// secretRandom) where secretRandom
    /// is a random bytes32 value.
    /// The sent ether is only refunded if the above scheme is followed correctly 
    /// and the commitment is correctly revealed in the
    /// revealing phase. The commitment is valid if the
    /// ether sent together with it is at least "depoistValue".
    /// Each address can only use this function once
    function commit(bytes32 _blindedHand) payable external onlyBefore(commitEnd) {
        require(msg.sender == firstParticipant || msg.sender == secondParticipant,"Unknown Participant");
        require(!blindedHands[msg.sender][0].commited,"Already Commited");
        require(msg.value >= depositValue,"Invalid Deposit Amount");
        blindedHands[msg.sender][0].blindedHand = _blindedHand;
        blindedHands[msg.sender][0].deposit = msg.value;
        blindedHands[msg.sender][0].commited = true;
    }

    /// Reveal your blinded hand. You will get a refund of your deposit for the
    /// correctly blinded and revealed hand.
    function reveal(uint _hand, bytes32 random) external onlyAfter(commitEnd) onlyBefore(revealEnd){
        require(blindedHands[msg.sender][0].commited,"You have not commited");
        require(!blindedHands[msg.sender][0].revealed,"Already Revealed");
        blindHand memory handToCheck = blindedHands[msg.sender][0];
        notRefunded += handToCheck.deposit;

       if(handToCheck.blindedHand != keccak256(abi.encodePacked(_hand,random))){    
           emit commitmentDoesNotMatch(msg.sender);
        }
        else{
             if(_hand == 1 || _hand == 2 || _hand == 3){   
                notRefunded -= handToCheck.deposit;
                blindedHands[msg.sender][0].deposit = 0;
                blindedHands[msg.sender][0].revealed = true;
                payable(msg.sender).transfer(handToCheck.deposit);
                participantHands[i].hand = _hand;
                participantHands[i].participant = msg.sender;
                i++;
            }
             else{   
                emit schemeNotFollowed(msg.sender);
            }
        }        
    }

    function end() external onlyAfter(revealEnd) returns (bool _state){
        require(!ended,"The protocol has already completed");
        ended = true;

        bool firstReveal = blindedHands[firstParticipant][0].revealed;
        bool secondReveal = blindedHands[secondParticipant][0].revealed;

        if( !firstReveal && !secondReveal )//if neither followed the protocol correctly 
        {   payable(manager).transfer(reward + notRefunded);
            emit neitherParticipantfollowed();
            return true;
        }
        
        if( !firstReveal && secondReveal)//if only one follwed the protocol correctly
        {   payable(secondParticipant).transfer(reward);
            payable(manager).transfer(notRefunded);
            emit participantDidNotFollow(firstParticipant);
            return true;    
        }
        if( firstReveal && !secondReveal ){
            payable(firstParticipant).transfer(reward);
            payable(manager).transfer(notRefunded);
            emit participantDidNotFollow(secondParticipant);
            return true;
        }

        else{
            uint win = calculateWinner();
            if(win == 0){    
                emit tie(firstParticipant, secondParticipant);
                uint split = reward/2;
                payable(firstParticipant).transfer(split);
                payable(secondParticipant).transfer(split);
                return true;
            }
            else if(win == 1){
                emit winnerSelected(participantHands[0].participant);
                payable(participantHands[0].participant).transfer(reward);
                return true;
            } 
            else if(win == 2){
                emit winnerSelected(participantHands[1].participant);
                payable(participantHands[1].participant).transfer(reward);
                return true;
            }
        }
    }

    function calculateWinner() internal view returns (uint _win) {
        uint participant1 = participantHands[0].hand;
        uint participant2 = participantHands[1].hand;
        if(participant1 == participant2)
            return 0;
        if(participant1 > participant2)
            if(participant1 == 3 && participant2 == 1)
                return 2;
        else 
            return 1;
        if(participant2 > participant1)
            if(participant2 == 3 && participant1 == 1)
                return 1;
        else 
            return 2;        
    } 

}
