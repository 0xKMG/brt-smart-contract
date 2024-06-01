// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import { IEventContract } from "./IEventContract.sol";

contract EventContract is IEventContract, Initializable, OwnableUpgradeable {
    using SafeERC20 for IERC20;
    uint256 public eventCount;
    IERC20 public token; // based token for penalty
    mapping(uint256 => Event) public events;
    mapping(address => uint256[]) public joinedEvents;
    mapping(address => uint256) public lateCount;
    mapping(address => uint256) public eventCountByUser;
    mapping(address => uint256) public userClaimableAmount;

    function initialize(address _token) public initializer {
        token = IERC20(_token);
        __Ownable_init(msg.sender);
    }

    function createEvent(
        string memory _name,
        uint256 _regDeadline, //timestamp for registration deadline
        uint256 _arrivalTime, //timestamp for event start time
        uint256 commitment,
        uint256 penalty,
        address[] memory _invitees
    )
        public
        // ValidationMode _validationMode,
        // PenaltyMode _penaltyMode,

        onlyOwner
    {
        require(penalty < commitment, "Penalty should be less than commitment");
        eventCount++;
        Event storage newEvent = events[eventCount];
        newEvent.eventId = eventCount;
        newEvent.name = _name;
        newEvent.regDeadline = _regDeadline;
        newEvent.arrivalTime = _arrivalTime;
        newEvent.isEnded = false;
        newEvent.commitmentRequired = commitment;
        // newEvent.validationMode = _validationMode;
        // newEvent.penaltyMode = _penaltyMode;
        inviteUsers(eventCount, _invitees);

        emit EventCreated(eventCount, _name, _regDeadline, _arrivalTime);
    }

    //function to invite an array of users
    function inviteUsers(uint256 _eventId, address[] memory _invitees) public onlyOwner {
        for (uint256 i; i < _invitees.length; ) {
            inviteUser(_eventId, _invitees[i]);
            unchecked {
                ++i;
            }
        }
    }

    function inviteUser(uint256 _eventId, address _invitee) public onlyOwner {
        Event storage myEvent = events[_eventId];
        require(myEvent.participantStatus[_invitee] == UserStatus.Invited, "User already invited");
        myEvent.participantStatus[_invitee] = UserStatus.Invited;

        emit UserInvited(_eventId, _invitee);
    }

    function acceptInvite(uint256 _eventId) public {
        //safe transfer commitment amount to contract
        Event storage myEvent = events[_eventId];
        require(myEvent.participantStatus[msg.sender] == UserStatus.Invited, "No invitation found");
        require(block.timestamp <= myEvent.regDeadline, "Registration deadline passed");

        //CEI not implemented
        token.safeTransferFrom(msg.sender, address(this), events[_eventId].commitmentRequired);
        userClaimableAmount[msg.sender] += events[_eventId].commitmentRequired;
        myEvent.participantStatus[msg.sender] = UserStatus.Accepted;
        myEvent.participantList.push(msg.sender);
        joinedEvents[msg.sender].push(_eventId);
        myEvent.totalCommitment += myEvent.commitmentRequired;
        eventCountByUser[msg.sender]++;

        emit UserAccepted(_eventId, msg.sender);
    }

    //@todo implement chainlink upkeep here
    function checkArrivals(uint256 _eventId) public {
        Event storage myEvent = events[_eventId];
        require(block.timestamp >= myEvent.arrivalTime, "Event has not started");
        require(!myEvent.isEnded, "Event already ended");

        for (uint256 i; i < myEvent.participantList.length; ) {
            bool onTime = validateArrival(_eventId, myEvent.participantList[i]);
            if (!onTime) {
                lateCount[myEvent.participantList[i]]++;
                // Handle penalty distribution based on penalty mode
                handlePenalty(_eventId, myEvent.participantList[i]);
                myEvent.penalties += myEvent.penalties;
            } else {
                myEvent.onTimeParticipants.push(myEvent.participantList[i]);
            }
            emit UserCheckedArrival(_eventId, myEvent.participantList[i], onTime);
            unchecked {
                ++i;
            }
        }
        //distribute the penalty to the ontime participants in claimableAmount 
        for (uint256 i; i < myEvent.onTimeParticipants.length; ) {
            userClaimableAmount[myEvent.onTimeParticipants[i]] += myEvent.penalties / myEvent.onTimeParticipants.length;
            unchecked {
                ++i;
            }
        }



        myEvent.isEnded = true;
    }

    function validateArrival(uint256 _eventId, address _participant) internal view returns (bool) {
        // Implement validation logic based on validation mode
        // Example: Chainlink oracle, voting, or NFC validation
        return true;
    }

    function handlePenalty(uint256 _eventId, address _participant) internal {
        // Implement penalty distribution based on penalty mode
        // Example: Harsh, Moderate, or Lenient penalty
        //minus the calimable
        userClaimableAmount[_participant] -= events[_eventId].penalties;
    }

    function getUserJoinedEvents(address _user) public view returns (uint256[] memory) {
        return joinedEvents[_user];
    }

    function getUserLateCount(address _user) public view returns (uint256) {
        return lateCount[_user];
    }

    //claim the claimable amount
    function claim() public {
        require(userClaimableAmount[msg.sender] > 0, "No claimable amount");
        userClaimableAmount[msg.sender] = 0;
        token.safeTransfer(msg.sender, userClaimableAmount[msg.sender]);
    }
}
