// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FunctionsConsumerDecoder } from "./FunctionsConsumerDecoder.sol";
import { AutomationCompatibleInterface } from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IBeRightThere } from "./IBeRightThere.sol";

//This is an implementation with Chainlink Automation and Chainlink Functions
contract BeRightThereV2 is AutomationCompatibleInterface, IBeRightThere, Initializable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    uint256 public eventCount;
    address chainlinkKeeper; // Chainlink Keeper address
    FunctionsConsumerDecoder public functionsConsumer;
    IERC20 public token; // based token for penalty
    mapping(uint256 => Event) public events;
    mapping(address => uint256[]) public joinedEvents;
    mapping(address => uint256[]) public invitedEvents;
    uint256[] public activeEvents;
    mapping(address => UserInfo) public userInfo;
    mapping(uint256 => uint256) public eventUpkeepTime; // New state variable to track when upkeep is needed
    mapping(uint256 => bool) public allValidationsComplete;

    // Add storage gap
    uint256[50] private __gap;

    // ============================
    // Constructor and Initialization
    // ============================

    /**
     * @dev Initializes the contract with the specified token address.
     * @param _token The address of the token contract.
     */
    function initialize(address _token) public initializer {
        token = IERC20(_token);
        __Ownable_init(msg.sender);
    }

    // ============================
    // Chainlink Functions
    // ============================

    /**
     * @notice Sets the Chainlink keeper and functions consumer addresses.
     * @param _chainlinkKeeper The address of the Chainlink keeper.
     * @param _functionsConsumer The address of the functions consumer.
     */
    function setChainlinkConfig(address _chainlinkKeeper, address _functionsConsumer) public onlyOwner {
        chainlinkKeeper = _chainlinkKeeper;
        functionsConsumer = FunctionsConsumerDecoder(_functionsConsumer);
        emit ChainlinkKeeperSet(_chainlinkKeeper, _functionsConsumer);
    }

    // ============================
    // Event Management
    // ============================

    /**
     * @notice Creates a new event with the specified parameters.
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

    /**
     * @notice Invites a user to an event.
     * @param _eventId The ID of the event.
     * @param _invitee The address of the invitee.
     */
    function inviteUser(uint256 _eventId, address _invitee) public onlyOwner {
        Event storage myEvent = events[_eventId];
        require(myEvent.participantStatus[_invitee] == UserStatus.Invited, "User already invited");
        myEvent.participantStatus[_invitee] = UserStatus.Invited;
        invitedEvents[_invitee].push(_eventId);
        emit UserInvited(_eventId, _invitee);
    }

    /**
     * @notice Invites multiple users to an event.
     * @param _eventId The ID of the event.
     * @param _invitees The addresses of the invitees.
     */
    function inviteUsers(uint256 _eventId, address[] memory _invitees) public onlyOwner {
        for (uint256 i; i < _invitees.length; ) {
            inviteUser(_eventId, _invitees[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Accepts an invite to an event.
     * @param _eventId The ID of the event.
     */
    function acceptInvite(uint256 _eventId) public {
        Event storage myEvent = events[_eventId];
        require(myEvent.participantStatus[msg.sender] == UserStatus.Invited, "No invitation found");
        require(block.timestamp <= myEvent.regDeadline, "Registration deadline passed");

        _acceptInvite(_eventId);

        emit UserAccepted(_eventId, msg.sender);
    }

    // ============================
    // Validation and Upkeep
    // ============================

    /**
     * @notice Checks arrivals for an event and triggers validation.
     * @param _eventId The ID of the event.
     */
    function checkArrivals(uint256 _eventId) public {
        Event storage myEvent = events[_eventId];
        require(block.timestamp >= myEvent.arrivalTime, "Event has not started");
        require(!myEvent.isEnded, "Event already ended");

        for (uint256 i = 0; i < myEvent.participantList.length; i++) {
            address participant = myEvent.participantList[i];

            // Prepare arguments
            string[] memory args = new string[](2);
            args[0] = uint2str(_eventId);
            args[1] = addressToString(participant);

            bytes[] memory bytesArgs = new bytes[](0); // Empty bytes array

            // Trigger Chainlink Function to validate arrival
            functionsConsumer.sendRequest(
                "return {isValid: true}", // Inline JavaScript source
                new bytes(0), // Encrypted secrets (empty in this case)
                0, // DON hosted secrets slotID (not used)
                0, // DON hosted secrets version (not used)
                args, // Arguments for the function
                bytesArgs, // Bytes arguments (empty)
                0, // Subscription ID (set accordingly)
                200000, // Gas limit
                bytes32(0) // DON ID (set accordingly)
            );
        }
    }

    /**
     * @notice Checks if upkeep is needed.
     * @param  data to check.
     * @return upkeepNeeded A boolean indicating if upkeep is needed.
     * @return performData The data to perform the upkeep.
     */
    function checkUpkeep(bytes calldata data) external view override returns (bool upkeepNeeded, bytes memory performData) {
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

    /**
     * @notice Performs the upkeep.
     * @param performData The data to perform the upkeep.
     */
    function performUpkeep(bytes calldata performData) external override {
        uint256 eventId = abi.decode(performData, (uint256));
        if (block.timestamp >= eventUpkeepTime[eventId]) {
            processValidationResponse(eventId);
        }
    }

    // ============================
    // Internal Functions
    // ============================

    /**
     * @dev Processes the validation response.
     * @param eventId The ID of the event.
     */
    function processValidationResponse(uint256 eventId) public {
        Event storage myEvent = events[eventId];
        require(!myEvent.isEnded, "Event already ended");

        bool allResponsesReceived = true;

        for (uint256 i = 0; i < myEvent.participantList.length; i++) {
            address participant = myEvent.participantList[i];
            bool onTime = functionsConsumer.validationStatus(eventId, participant);

            // Custom logic to check if the response has been received
            if (functionsConsumer.s_lastRequestId() != keccak256(abi.encode(eventId, participant))) {
                allResponsesReceived = false;
                continue;
            }

            if (!onTime) {
                userInfo[participant].lateCount++;
                _handlePenalty(eventId, participant);
                myEvent.penalties += myEvent.penaltyRequired;
            } else {
                myEvent.onTimeParticipants.push(participant);
            }
        }

        if (allResponsesReceived) {
            distributeRewards(eventId);
            myEvent.isEnded = true;
                        allValidationsComplete[eventId] = true;
            _deleteEvent(eventId);
        }
    }

    /**
     * @dev Distributes rewards to participants.
     * @param eventId The ID of the event.
     */
    function distributeRewards(uint256 eventId) internal {
        Event storage myEvent = events[eventId];
        uint256 rewardPerParticipant = myEvent.penalties / myEvent.onTimeParticipants.length;

        for (uint256 i = 0; i < myEvent.onTimeParticipants.length; i++) {
            address participant = myEvent.onTimeParticipants[i];
            userInfo[participant].userClaimableAmount += rewardPerParticipant;
        }
    }

    /**
     * @dev Validates the arrival of a participant.
     * @param _eventId The ID of the event.
     * @param _participant The address of the participant.
     * @return A boolean indicating if the participant arrived on time.
     */
    function validateArrival(uint256 _eventId, address _participant) internal view returns (bool) {
        return functionsConsumer.validationStatus(_eventId, _participant);
    }

    /**
     * @dev Handles penalty for late participants.
     * @param _eventId The ID of the event.
     * @param _participant The address of the participant.
     */
    function _handlePenalty(uint256 _eventId, address _participant) internal {
        userInfo[_participant].userClaimableAmount -= events[_eventId].penaltyRequired;
        userInfo[_participant].userTotalPenalties += events[_eventId].penaltyRequired;
    }

    /**
     * @dev Deletes an event from the active events list.
     * @param _eventId The ID of the event to be deleted.
     */
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

    /**
     * @dev Accepts an invite for an event.
     * @param _eventId The ID of the event.
     */
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

    /**
     * @dev Checks if validation is ready for an event.
     * @param _eventId The ID of the event.
     * @return A boolean indicating if validation is ready.
     */
    function _isValidationReady(uint256 _eventId) internal view returns (bool) {
        Event storage myEvent = events[_eventId];
        return block.timestamp >= myEvent.arrivalTime - 600 && block.timestamp <= myEvent.arrivalTime + 600;
    }

    /**
     * @dev Checks if a participant has accepted an event invite but the event is not ended.
     * @param eventDetails The details of the event.
     * @param _user The address of the user.
     * @return A boolean indicating if the user has accepted but the event is not ended.
     */
    function _isAcceptedButNotEnded(Event storage eventDetails, address _user) internal view returns (bool) {
        return eventDetails.participantStatus[_user] == UserStatus.Accepted && !eventDetails.isEnded;
    }

    /**
     * @dev Checks if a participant has accepted an event invite and the event has ended.
     * @param eventDetails The details of the event.
     * @param _user The address of the user.
     * @return A boolean indicating if the user has accepted and the event has ended.
     */
    function _isAcceptedAndEnded(Event storage eventDetails, address _user) internal view returns (bool) {
        return eventDetails.participantStatus[_user] == UserStatus.Accepted && eventDetails.isEnded;
    }

    /**
     * @dev Checks if a participant has not accepted an event invite and the event is not ended.
     * @param eventDetails The details of the event.
     * @param _user The address of the user.
     * @return A boolean indicating if the user has not accepted and the event is not ended.
     */
    function _isNotAcceptedAndNotEnded(Event storage eventDetails, address _user) internal view returns (bool) {
        return eventDetails.participantStatus[_user] != UserStatus.Accepted && !eventDetails.isEnded;
    }

    /**
     * @dev Creates an event view struct from event details.
     * @param eventDetails The details of the event.
     * @return The event view struct.
     */
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

    // ============================
    // Helper Functions
    // ============================

    /**
     * @dev Converts a uint256 to a string.
     * @param _i The uint256 value to convert.
     * @return The string representation of the uint256 value.
     */
    function uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    /**
     * @dev Converts an address to a string.
     * @param _addr The address to convert.
     * @return The string representation of the address.
     */
    function addressToString(address _addr) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(42);
        str[0] = "0";
        str[1] = "x";
        for (uint256 i = 0; i < 20; i++) {
            str[2 + i * 2] = alphabet[uint8(value[i + 12] >> 4)];
            str[3 + i * 2] = alphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }
}
