// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import { AutomationCompatibleInterface } from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IBeRightThere } from "./IBeRightThere.sol";

contract BeRightThereV1 is AutomationCompatibleInterface, IBeRightThere, Initializable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    uint256 public eventCount;
    IERC20 public token; // based token for penalty
    mapping(uint256 => Event) public events;
    mapping(address => uint256[]) public joinedEvents;
    mapping(address => uint256[]) public invitedEvents;
    uint256[] public activeEvents;
    mapping(address => UserInfo) public userInfo;
    mapping(uint256 => uint256) public eventUpkeepTime; // New state variable to track when upkeep is needed

    //add storage gap
    uint256[50] private __gap;

    function initialize(address _token) public initializer {
        token = IERC20(_token);
        __Ownable_init(msg.sender);
    }

    /**
     * @dev Creates a new event with the specified parameters.
     * @param _name The name of the event.
     * @param _regDeadline The registration deadline for the event.
     * @param _arrivalTime The scheduled arrival time for the event.
     * @param commitment The amount required as a commitment to the event.
     * @param penalty The penalty amount for being late.
     * @param _location The encoded location of the event.
     * @param _invitees The addresses of the invitees.
     */
    function createEvent(
        string memory _name,
        uint256 _regDeadline, // timestamp for registration deadline
        uint256 _arrivalTime, // timestamp for event start time
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
        inviteUsers(eventCount, _invitees);

        emit EventCreated(eventCount, _name, _regDeadline, _arrivalTime, _location);
    }

    function inviteUser(uint256 _eventId, address _invitee) public onlyOwner {
        Event storage myEvent = events[_eventId];
        require(myEvent.participantStatus[_invitee] == UserStatus.Invited, "User already invited");
        myEvent.participantStatus[_invitee] = UserStatus.Invited;
        invitedEvents[_invitee].push(_eventId);
        emit UserInvited(_eventId, _invitee);
    }

    function inviteUsers(uint256 _eventId, address[] memory _invitees) public onlyOwner {
        for (uint256 i; i < _invitees.length; ) {
            inviteUser(_eventId, _invitees[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Accepts an invite to an event.
     * @param _eventId The ID of the event.
     */
    function acceptInvite(uint256 _eventId) public {
        Event storage myEvent = events[_eventId];
        require(myEvent.participantStatus[msg.sender] == UserStatus.Invited, "No invitation found");
        require(block.timestamp <= myEvent.regDeadline, "Registration deadline passed");

        _acceptInvite(_eventId);

        emit UserAccepted(_eventId, msg.sender);
    }

    /**
     * @dev Checks arrivals of all participants for a specific event.
     * @param _eventId The ID of the event.
     */
    function _checkArrivals(uint256 _eventId) internal {
        Event storage myEvent = events[_eventId];
        require(block.timestamp >= myEvent.arrivalTime, "Event has not started");
        require(!myEvent.isEnded, "Event already ended");

        for (uint256 i; i < myEvent.participantList.length; ) {
            bool onTime = validateArrival(_eventId, myEvent.participantList[i]);
            if (!onTime) {
                userInfo[myEvent.participantList[i]].lateCount++;
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
            userInfo[myEvent.onTimeParticipants[i]].userClaimableAmount += myEvent.penalties / myEvent.onTimeParticipants.length;
            unchecked {
                ++i;
            }
        }

        myEvent.isEnded = true;
        _deleteEvent(_eventId);
    }

    function validateArrival(uint256 _eventId, address participant) internal view returns (bool) {
        // Implement validation logic
        return true;
    }

    /**
     * @dev Claims the user's claimable amount.
     */
    function claim() public {
        require(userInfo[msg.sender].userClaimableAmount > 0, "No claimable amount");
        uint256 amount = userInfo[msg.sender].userClaimableAmount;
        userInfo[msg.sender].userClaimableAmount = 0;
        userInfo[msg.sender].userTotalClaimed += amount;
        token.safeTransfer(msg.sender, amount);
        emit Claimed(msg.sender, amount);
    }

    /**
     * @dev Returns the events that the user has joined.
     * @param _user The address of the user.
     * @return The array of event IDs that the user has joined.
     */
    function getUserJoinedEvents(address _user) public view returns (uint256[] memory) {
        return joinedEvents[_user];
    }

    /**
     * @dev Returns the late count for a user.
     * @param _user The address of the user.
     * @return The count of late occurrences.
     */
    function getUserLateCount(address _user) public view returns (uint256) {
        return userInfo[_user].lateCount;
    }

    /**
     * @dev Decodes the coordinates from bytes32 format.
     * @param encoded The encoded coordinates.
     * @return latitude and longitude.
     */
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

    /**
     * @dev Returns the user's total contribution.
     * @param _user The address of the user.
     * @return The total contribution amount.
     */
    function getUserContribution(address _user) public view returns (uint256) {
        return userInfo[_user].userTotalContribution;
    }

    /**
     * @dev Returns the user's total claimed amount.
     * @param _user The address of the user.
     * @return The total claimed amount.
     */
    function getUserClaimed(address _user) public view returns (uint256) {
        return userInfo[_user].userTotalClaimed;
    }

    /**
     * @dev Returns the user's total penalties.
     * @param _user The address of the user.
     * @return The total penalties amount.
     */
    function getUserPenalties(address _user) public view returns (uint256) {
        return userInfo[_user].userTotalPenalties;
    }

    /**
     * @dev Checks if the validation is ready for a list of events.
     * @param _eventIds The array of event IDs.
     * @return The array of booleans indicating if validation is ready.
     */
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

    /**
     * @dev Returns the events that the user has been invited to.
     * @param _user The address of the user.
     * @return The array of EventView structs.
     */
    function getInvitedEvents(address _user) public view returns (EventView[] memory) {
        uint256[] memory eventIds = invitedEvents[_user];
        uint256 length = eventIds.length;

        EventView[] memory eventsView = new EventView[](length);

        for (uint256 i = 0; i < length; i++) {
            Event storage eventDetails = events[eventIds[i]];
            eventsView[i] = _createEventView(eventDetails);
        }

        return eventsView;
    }

    /**
     * @dev Returns the pending events for a user.
     * @param _user The address of the user.
     * @return The array of EventView structs.
     */
    function getPendingEvents(address _user) public view returns (EventView[] memory) {
        uint256[] memory eventIds = invitedEvents[_user];
        uint256 length = eventIds.length;

        EventView[] memory eventsView = new EventView[](length);

        for (uint256 i = 0; i < length; i++) {
            Event storage eventDetails = events[eventIds[i]];
            if (eventDetails.participantStatus[_user] == UserStatus.Invited) {
                eventsView[i] = _createEventView(eventDetails);
            }
        }

        return eventsView;
    }

    /**
     * @dev Returns the user's events based on their status.
     * @param _user The address of the user.
     * @param isEnded Whether the event has ended.
     * @param isAccepted Whether the user has accepted the invite.
     * @return The array of EventView structs.
     */
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

    function _acceptInvite(uint256 _eventId) internal {
        Event storage myEvent = events[_eventId];
        token.safeTransferFrom(msg.sender, address(this), myEvent.commitmentRequired);
        userInfo[msg.sender].userClaimableAmount += myEvent.commitmentRequired;
        myEvent.participantStatus[msg.sender] = UserStatus.Accepted;
        myEvent.participantList.push(msg.sender);
        joinedEvents[msg.sender].push(_eventId);
        myEvent.totalCommitment += myEvent.commitmentRequired;
        userInfo[msg.sender].userTotalContribution += myEvent.commitmentRequired;
        userInfo[msg.sender].eventCountByUser++;
    }

    function _isValidationReady(uint256 _eventId) internal view returns (bool) {
        Event storage myEvent = events[_eventId];
        return block.timestamp >= myEvent.arrivalTime - 600 && block.timestamp <= myEvent.arrivalTime + 600;
    }

    function _handlePenalty(uint256 _eventId, address _participant) internal {
        userInfo[_participant].userClaimableAmount -= events[_eventId].penaltyRequired;
        userInfo[_participant].userTotalPenalties += events[_eventId].penaltyRequired;
    }

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

    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory performData) {
        uint256[] memory eventIds = activeEvents;
        for (uint256 i = 0; i < eventIds.length; i++) {
            if (block.timestamp >= eventUpkeepTime[eventIds[i]] && !events[eventIds[i]].isEnded) {
                upkeepNeeded = true;
                performData = abi.encode(eventIds[i]);
                return (upkeepNeeded, performData);
            }
        }
        upkeepNeeded = false;
        performData = "";
    }

    function performUpkeep(bytes calldata performData) external override {
        uint256 eventId = abi.decode(performData, (uint256));
        if (block.timestamp >= eventUpkeepTime[eventId]) {
            _checkArrivals(eventId);
        }
    }

}
