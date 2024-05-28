# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.ts
```

# EventContract

## Overview

`EventContract` is a smart contract designed for event organizers to manage event participants. It allows organizers to invite participants, enforce penalties for late arrivals, and handle user deposits. The contract is upgradeable using OpenZeppelin's upgradeable contract library.

## Installation

To use this contract, you need to install the necessary dependencies:

```sh
npm install @openzeppelin/contracts-upgradeable
```

## Contract Functions

### `initialize()`

Initializes the contract and sets the contract owner. This function is called only once during contract deployment.

**Modifiers:**

- `initializer`

### `createEvent(string memory _name, uint256 _regDeadline, uint256 _arrivalTime, ValidationMode _validationMode, PenaltyMode _penaltyMode) public onlyOwner`

Creates a new event with the specified parameters.

**Parameters:**

- `_name`: The name of the event.
- `_regDeadline`: The registration deadline for the event.
- `_arrivalTime`: The scheduled arrival time for the event.
- `_validationMode`: The mode of validation for arrival (Chainlink, Vote, NFC).
- `_penaltyMode`: The mode of penalty enforcement (Harsh, Moderate, Lenient).

**Modifiers:**

- `onlyOwner`

**Emits:**

- `EventCreated(uint256 eventId, string name, uint256 regDeadline, uint256 arrivalTime)`

### `inviteUser(uint256 _eventId, address _invitee) public onlyOwner`

Invites a user to participate in an event.

**Parameters:**

- `_eventId`: The ID of the event.
- `_invitee`: The address of the user to be invited.

**Modifiers:**

- `onlyOwner`

**Emits:**

- `UserInvited(uint256 eventId, address invitee)`

### `acceptInvite(uint256 _eventId) public payable`

Allows an invited user to accept the invitation and pay the deposit to join the event.

**Parameters:**

- `_eventId`: The ID of the event.

**Requirements:**

- The caller must be invited.
- The current timestamp must be before the registration deadline.
- The correct deposit amount must be sent with the transaction.

**Emits:**

- `UserAccepted(uint256 eventId, address participant)`

### `checkArrival(uint256 _eventId, address _participant) public onlyOwner`

Checks whether a participant arrived on time for the event and applies penalties if necessary.

**Parameters:**

- `_eventId`: The ID of the event.
- `_participant`: The address of the participant to be checked.

**Modifiers:**

- `onlyOwner`

**Emits:**

- `UserCheckedArrival(uint256 eventId, address participant, bool onTime)`

### `validateArrival(uint256 _eventId, address _participant) internal view returns (bool)`

Validates the arrival of a participant. This is a placeholder function to be implemented with the appropriate logic for arrival validation.

**Parameters:**

- `_eventId`: The ID of the event.
- `_participant`: The address of the participant.

**Returns:**

- `bool`: Whether the participant arrived on time.

### `handlePenalty(uint256 _eventId, address _participant) internal`

Handles the distribution of penalties to participants who did not arrive on time. This is a placeholder function to be implemented with the appropriate logic for penalty distribution.

**Parameters:**

- `_eventId`: The ID of the event.
- `_participant`: The address of the participant.

### `getUserJoinedEvents(address _user) public view returns (uint256[] memory)`

Returns a list of event IDs that the user has joined.

**Parameters:**

- `_user`: The address of the user.

**Returns:**

- `uint256[]`: An array of event IDs.

### `getUserLateCount(address _user) public view returns (uint256)`

Returns the number of times a user was late for events.

**Parameters:**

- `_user`: The address of the user.

**Returns:**

- `uint256`: The count of late occurrences.

## Events

### `EventCreated(uint256 eventId, string name, uint256 regDeadline, uint256 arrivalTime)`

Emitted when a new event is created.

**Parameters:**

- `eventId`: The ID of the event.
- `name`: The name of the event.
- `regDeadline`: The registration deadline for the event.
- `arrivalTime`: The scheduled arrival time for the event.

### `UserInvited(uint256 eventId, address invitee)`

Emitted when a user is invited to an event.

**Parameters:**

- `eventId`: The ID of the event.
- `invitee`: The address of the invited user.

### `UserAccepted(uint256 eventId, address participant)`

Emitted when an invited user accepts the invitation and joins the event.

**Parameters:**

- `eventId`: The ID of the event.
- `participant`: The address of the participant.

### `UserCheckedArrival(uint256 eventId, address participant, bool onTime)`

Emitted when a participant's arrival is checked and validated.

**Parameters:**

- `eventId`: The ID of the event.
- `participant`: The address of the participant.
- `onTime`: Whether the participant arrived on time.
