// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


import {IEventContract} from "./IEventContract.sol";

contract EventContract is IEventContract, Initializable, OwnableUpgradeable {
    uint256 public eventCount;

    mapping(uint256 => Event) public events;
    mapping(address => uint256[]) public joinedEvents;
    mapping(address => uint256) public lateCount;
    mapping(address => uint256) public eventCountByUser;

    function initialize() public initializer {
        __Ownable_init(msg.sender);
    }

    function createEvent(
        string memory _name,
        uint256 _regDeadline,
        uint256 _arrivalTime,
        // ValidationMode _validationMode,
        // PenaltyMode _penaltyMode,
        address[] memory _invitees
    ) public onlyOwner {
        eventCount++;
        Event storage newEvent = events[eventCount];
        newEvent.eventId = eventCount;
        newEvent.name = _name;
        newEvent.regDeadline = _regDeadline;
        newEvent.arrivalTime = _arrivalTime;
        newEvent.isEnded = false;
        // newEvent.validationMode = _validationMode;
        // newEvent.penaltyMode = _penaltyMode;

        inviteUsers(eventCount, _invitees);

        emit EventCreated(eventCount, _name, _regDeadline, _arrivalTime);
    }

    //function to invite an array of users
    function inviteUsers(
        uint256 _eventId,
        address[] memory _invitees
    ) public onlyOwner {
        for (uint256 i; i < _invitees.length; ) {
            inviteUser(_eventId, _invitees[i]);
            unchecked {
                ++i;
            }
        }
    }

    function inviteUser(uint256 _eventId, address _invitee) public onlyOwner {
        Event storage myEvent = events[_eventId];
        require(
            myEvent.participantStatus[_invitee] == UserStatus.Invited,
            "User already invited"
        );
        myEvent.participantStatus[_invitee] = UserStatus.Invited;

        emit UserInvited(_eventId, _invitee);
    }

    function acceptInvite(uint256 _eventId) public payable {
        Event storage myEvent = events[_eventId];
        require(
            myEvent.participantStatus[msg.sender] == UserStatus.Invited,
            "No invitation found"
        );
        require(
            block.timestamp <= myEvent.regDeadline,
            "Registration deadline passed"
        );

        myEvent.participantStatus[msg.sender] = UserStatus.Accepted;
        myEvent.participantList.push(msg.sender);
        joinedEvents[msg.sender].push(_eventId);
        eventCountByUser[msg.sender]++;

        emit UserAccepted(_eventId, msg.sender);
    }

    function checkArrival(
        uint256 _eventId,
        address _participant
    ) public onlyOwner {
        Event storage myEvent = events[_eventId];
        require(
            myEvent.participantStatus[_participant] == UserStatus.Accepted,
            "User not accepted"
        );
        require(
            block.timestamp >= myEvent.arrivalTime,
            "Event has not started"
        );
        require(!myEvent.isEnded, "Event already ended");

        bool onTime = validateArrival(_eventId, _participant);
        if (!onTime) {
            lateCount[_participant]++;
            // Handle penalty distribution based on penalty mode
            handlePenalty(_eventId, _participant);
        }

        myEvent.isEnded = true;
        emit UserCheckedArrival(_eventId, _participant, onTime);
    }

    function validateArrival(
        uint256 _eventId,
        address _participant
    ) internal view returns (bool) {
        // Implement validation logic based on validation mode
        // Example: Chainlink oracle, voting, or NFC validation
        return true;
    }

    function handlePenalty(uint256 _eventId, address _participant) internal {
        // Implement penalty distribution based on penalty mode
        // Example: Harsh, Moderate, or Lenient penalty
    }

    function getUserJoinedEvents(
        address _user
    ) public view returns (uint256[] memory) {
        return joinedEvents[_user];
    }

    function getUserLateCount(address _user) public view returns (uint256) {
        return lateCount[_user];
    }
}
