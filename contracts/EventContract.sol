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

    mapping(uint256 => mapping(address => bool)) public mockValidation; //event id to user to validation status

    //add storage gap
    uint256[50] private __gap;

    mapping(address => uint256[]) public invitedEvents;
    uint256[] public activeEvents;
    mapping(address => uint256) public userTotalContribution;
    mapping(address => uint256) public userTotalClaimed;
    mapping(address => uint256) public userTotalPenalties;

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
        bytes32 _location,
        address[] memory _invitees
    ) public {
        require(penalty < commitment, "Penalty should be less than commitment");
        eventCount++;
        Event storage newEvent = events[eventCount];
        newEvent.eventId = eventCount;
        newEvent.name = _name;
        newEvent.regDeadline = _regDeadline;
        newEvent.arrivalTime = _arrivalTime;
        newEvent.isEnded = false;
        newEvent.commitmentRequired = commitment;
        newEvent.location = _location;
        activeEvents.push(eventCount);
        newEvent.penaltyRequired = penalty;
        // _acceptInvite(newEvent.eventId);
        inviteUsers(eventCount, _invitees);

        emit EventCreated(eventCount, _name, _regDeadline, _arrivalTime, _location);
    }

    function decodeCoordinates(bytes32 encoded) public pure returns (int256 latitude, int256 longitude) {
        uint128 lat = uint128(uint256(encoded) >> 128);
        uint128 lon = uint128(uint256(encoded) & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);

        latitude = int256(int128(lat));
        longitude = int256(int128(lon));
    }

    function encodeCoordinates(int256 latitude, int256 longitude) public pure returns (bytes32) {
        int128 lat = int128(latitude);
        int128 lon = int128(longitude);

        bytes32 encoded;

        assembly {
            encoded := or(shl(128, lat), and(lon, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF))
        }

        return encoded;
    }

    function acceptInvite(uint256 _eventId) public {
        Event storage myEvent = events[_eventId];
        require(myEvent.participantStatus[msg.sender] == UserStatus.Invited, "No invitation found");
        require(block.timestamp <= myEvent.regDeadline, "Registration deadline passed");

        _acceptInvite(_eventId);

        emit UserAccepted(_eventId, msg.sender);
    }

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
        invitedEvents[_invitee].push(_eventId);
        emit UserInvited(_eventId, _invitee);
    }

    function _acceptInvite(uint256 _eventId) internal {
        Event storage myEvent = events[_eventId];
        token.safeTransferFrom(msg.sender, address(this), myEvent.commitmentRequired);
        userClaimableAmount[msg.sender] += myEvent.commitmentRequired;
        myEvent.participantStatus[msg.sender] = UserStatus.Accepted;
        myEvent.participantList.push(msg.sender);
        joinedEvents[msg.sender].push(_eventId);
        myEvent.totalCommitment += myEvent.commitmentRequired;
        userTotalContribution[msg.sender] += myEvent.commitmentRequired;
        eventCountByUser[msg.sender]++;
    }

    function _isValidationReady(uint256 _eventId) internal view returns (bool) {
        Event storage myEvent = events[_eventId];
        return block.timestamp >= myEvent.arrivalTime - 600 && block.timestamp <= myEvent.arrivalTime + 600;
    }

    //will be trigger automatically in production
    function checkArrivals(uint256 _eventId) public {
        Event storage myEvent = events[_eventId];
        require(block.timestamp >= myEvent.arrivalTime, "Event has not started");
        require(!myEvent.isEnded, "Event already ended");

        for (uint256 i; i < myEvent.participantList.length; ) {
            bool onTime = validateArrivalMock(_eventId, myEvent.participantList[i]);
            if (!onTime) {
                lateCount[myEvent.participantList[i]]++;
                _handlePenalty(_eventId, myEvent.participantList[i]);
                myEvent.penalties += myEvent.penaltyRequired;
            } else {
                myEvent.onTimeParticipants.push(myEvent.participantList[i]);
            }
            emit UserCheckedArrival(_eventId, myEvent.participantList[i], onTime);
            unchecked {
                ++i;
            }
        }

        for (uint256 i; i < myEvent.onTimeParticipants.length; ) {
            userClaimableAmount[myEvent.onTimeParticipants[i]] += myEvent.penalties / myEvent.onTimeParticipants.length;
            unchecked {
                ++i;
            }
        }

        myEvent.isEnded = true;
        _deleteEvent(_eventId);
    }

    function validateArrival(uint256 _eventId, address _participant) internal view returns (bool) {
        // Implement validation logic
        return true;
    }

    //@note currently in use
    function validateArrivalMock(uint256 _eventId, address _participant) public view returns (bool) {
        return mockValidation[_eventId][_participant];
    }

    //@note currently in use
    function mockValidationTrue(uint256 _eventId, address _participant) public {
        require(_isValidationReady(_eventId), "Validation not ready");
        //require isInvited
        mockValidation[_eventId][_participant] = true;
    }

    function _handlePenalty(uint256 _eventId, address _participant) internal {
        userClaimableAmount[_participant] -= events[_eventId].penaltyRequired;
        userTotalPenalties[_participant] += events[_eventId].penaltyRequired;
    }

    function getUserJoinedEvents(address _user) public view returns (uint256[] memory) {
        return joinedEvents[_user];
    }

    function getUserLateCount(address _user) public view returns (uint256) {
        return lateCount[_user];
    }

    function claim() public {
        require(userClaimableAmount[msg.sender] > 0, "No claimable amount");
        uint256 amount = userClaimableAmount[msg.sender];
        userClaimableAmount[msg.sender] = 0;
        userTotalClaimed[msg.sender] += amount;
        token.safeTransfer(msg.sender, amount);
        emit Claimed(msg.sender, amount);
    }

    //function to delete a speicific event in activeEvents array, make a new array with all active events
    function _deleteEvent(uint256 _eventId) internal {
        uint256[] memory newActiveEvents = new uint256[](activeEvents.length - 1);
        uint256 j;
        for (uint256 i; i < activeEvents.length; ) {
            if (activeEvents[i] != _eventId) {
                newActiveEvents[j] = activeEvents[i];
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
        activeEvents = newActiveEvents;
    }

    function getInvitedEvents(address _user) public view returns (EventView[] memory) {
        uint256[] memory eventIds = invitedEvents[_user];
        uint256 length = eventIds.length;

        EventView[] memory eventsView = new EventView[](length);

        for (uint256 i = 0; i < length; i++) {
            Event storage eventDetails = events[eventIds[i]];
            eventsView[i] = EventView({
                eventId: eventDetails.eventId,
                name: eventDetails.name,
                regDeadline: eventDetails.regDeadline,
                arrivalTime: eventDetails.arrivalTime,
                isEnded: eventDetails.isEnded,
                participantList: eventDetails.participantList,
                onTimeParticipants: eventDetails.onTimeParticipants,
                penalties: eventDetails.penalties,
                commitmentRequired: eventDetails.commitmentRequired,
                totalCommitment: eventDetails.totalCommitment,
                location: eventDetails.location,
                penaltyRequired: eventDetails.penaltyRequired
            });
        }

        return eventsView;
    }

    function getPendingEvents(address _user) public view returns (EventView[] memory) {
        uint256[] memory eventIds = invitedEvents[_user];
        uint256 length = eventIds.length;

        EventView[] memory eventsView = new EventView[](length);

        for (uint256 i = 0; i < length; i++) {
            Event storage eventDetails = events[eventIds[i]];
            if (eventDetails.participantStatus[_user] == UserStatus.Invited) {
                eventsView[i] = EventView({
                    eventId: eventDetails.eventId,
                    name: eventDetails.name,
                    regDeadline: eventDetails.regDeadline,
                    arrivalTime: eventDetails.arrivalTime,
                    isEnded: eventDetails.isEnded,
                    participantList: eventDetails.participantList,
                    onTimeParticipants: eventDetails.onTimeParticipants,
                    penalties: eventDetails.penalties,
                    commitmentRequired: eventDetails.commitmentRequired,
                    totalCommitment: eventDetails.totalCommitment,
                    location: eventDetails.location,
                    penaltyRequired: eventDetails.penaltyRequired
                });
            }
        }

        return eventsView;
    }

    function getUserEvents(address _user, bool isEnded, bool isAccepted) public view returns (EventView[] memory) {
        uint256[] memory eventIds = invitedEvents[_user];
        uint256 length = eventIds.length;

        // Temporary storage for filtering events
        EventView[] memory tempEventsView = new EventView[](length);
        uint256 count = 0;

        for (uint256 i = 0; i < length; i++) {
            Event storage eventDetails = events[eventIds[i]];
            if (isAccepted && !isEnded && _isAcceptedButNotEnded(eventDetails, _user)) {
                tempEventsView[count] = _createEventView(eventDetails);
                count++;
            } else if (isAccepted && isEnded && _isAcceptedAndEnded(eventDetails, _user)) {
                tempEventsView[count] = _createEventView(eventDetails);
                count++;
            } else if (
                !isAccepted && !isEnded && _isNotAcceptedAndNotEnded(eventDetails, _user) && eventDetails.regDeadline > block.timestamp
            ) {
                tempEventsView[count] = _createEventView(eventDetails);
                count++;
            }
        }

        // Create a fixed-size array to return only the filtered events
        EventView[] memory eventsView = new EventView[](count);
        for (uint256 i = 0; i < count; i++) {
            eventsView[i] = tempEventsView[i];
        }

        return eventsView;
    }

    function _isAcceptedButNotEnded(Event storage eventDetails, address _user) internal view returns (bool) {
        return eventDetails.participantStatus[_user] == UserStatus.Accepted && !eventDetails.isEnded;
    }

    function _isAcceptedAndEnded(Event storage eventDetails, address _user) internal view returns (bool) {
        return eventDetails.participantStatus[_user] == UserStatus.Accepted && eventDetails.isEnded;
    }

    function _isNotAcceptedAndNotEnded(Event storage eventDetails, address _user) internal view returns (bool) {
        return eventDetails.participantStatus[_user] != UserStatus.Accepted && !eventDetails.isEnded;
    }

    function _createEventView(Event storage eventDetails) internal view returns (EventView memory) {
        return
            EventView({
                eventId: eventDetails.eventId,
                name: eventDetails.name,
                regDeadline: eventDetails.regDeadline,
                arrivalTime: eventDetails.arrivalTime,
                isEnded: eventDetails.isEnded,
                participantList: eventDetails.participantList,
                onTimeParticipants: eventDetails.onTimeParticipants,
                penalties: eventDetails.penalties,
                commitmentRequired: eventDetails.commitmentRequired,
                totalCommitment: eventDetails.totalCommitment,
                location: eventDetails.location,
                penaltyRequired: eventDetails.penaltyRequired
            });
    }

    //create an isValiation ready view function, enter an array of eventsId and check if they are ready for validation, (10mins before and after event end time), return an array of bool
    function isValidationReady(uint256[] memory _eventIds) public view returns (bool[] memory) {
        bool[] memory ready = new bool[](_eventIds.length);
        for (uint256 i; i < _eventIds.length; ) {
            ready[i] = _isValidationReady(_eventIds[i]);
            unchecked {
                ++i;
            }
        }
        return ready;
    }

    function getUserContribution(address _user) public view returns (uint256) {
        return userTotalContribution[_user];
    }

    function getUserClaimed(address _user) public view returns (uint256) {
        return userTotalClaimed[_user];
    }

    function getUserPenalties(address _user) public view returns (uint256) {
        return userTotalPenalties[_user];
    }
}
