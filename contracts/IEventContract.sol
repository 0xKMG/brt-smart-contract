// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IEventContract {
    struct Event {
        uint256 eventId;
        string name;
        uint256 regDeadline;
        uint256 arrivalTime;
        bool isEnded;
        mapping(address => UserStatus) participantStatus;
        address[] participantList;
        address[] onTimeParticipants;
        uint256 penalties;
        uint256 commitmentRequired;
        uint256 totalCommitment;
        bytes32 location;  // Encoded latitude and longitude
        ValidationMode validationMode;
        PenaltyMode penaltyMode;
    }
    enum UserStatus {
        Invited,
        Accepted
    }
    enum PenaltyMode {
        Strict,
        Moderate,
        Lenient
    }
    enum ValidationMode {
        Chainlink,
        Vote,
        NFC
    }

    event EventCreated(
        uint256 eventId,
        string name,
        uint256 regDeadline,
        uint256 arrivalTime
    );

    event UserInvited(uint256 eventId, address invitee);
    event UserAccepted(uint256 eventId, address participant);
    event UserCheckedArrival(uint256 eventId, address participant, bool onTime);
}
