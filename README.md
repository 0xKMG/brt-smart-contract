# BeRightThereV1
![Be Right There Thumbnail](https://github.com/0xKMG/brt-smart-contract/assets/83229800/9082006f-f392-4a85-ae89-bdc741ca2103)

## Overview

`BeRightThereV1` is a smart contract solution designed to promote punctuality through behavioral economics and gamification. This project aims to address the common issue of lateness in social gatherings by turning punctuality into a playful bet, incentivizing users to arrive on time through friendly wagers. Built on the Scroll testnet, this version leverages simple smart contract logic to manage event creation, participant tracking, and bet distribution without the use of Chainlink Functions and Chainlink Automation (For an implementation with Chainlink, check out [BeRightThereV2]( https://github.com/0xKMG/brt-smart-contract/tree/main/contracts/BeRightThereV2).

## How it Works 

![How it Works](https://github.com/0xKMG/brt-smart-contract/assets/83229800/14603209-8f39-4afb-9b88-ab317eb08d67)


## Installation

To deploy this project, install all dependencies:

```sh
npm install
```

## Contract Functions

### `initialize(address _token)`

Initializes the contract with the token address and sets the contract owner. This function is called only once during deployment.

**Modifiers:**

- `initializer`

### `createEvent`

```solidity
function createEvent(
    string memory _name,
    uint256 _regDeadline,
    uint256 _arrivalTime,
    uint256 commitment,
    uint256 penalty,
    bytes32 _location,
    address[] memory _invitees
) public onlyOwner
```

Creates a new event with specified parameters.

**Parameters:**

- `_name`: The name of the event.
- `_regDeadline`: The registration deadline.
- `_arrivalTime`: The scheduled arrival time.
- `commitment`: The amount of commitment required.
- `penalty`: The penalty for being late.
- `_location`: The encoded location of the event.
- `_invitees`: An array of addresses to invite.

**Modifiers:**

- `onlyOwner`

**Emits:**

- `EventCreated(uint256 eventId, string name, uint256 regDeadline, uint256 arrivalTime, bytes32 location)`

### `inviteUser`

```solidity
function inviteUser(uint256 _eventId, address _invitee) public onlyOwner
```

Invites a user to participate in an event.

**Parameters:**

- `_eventId`: The ID of the event.
- `_invitee`: The address of the user to be invited.

**Modifiers:**

- `onlyOwner`

**Emits:**

- `UserInvited(uint256 eventId, address invitee)`

### `inviteUsers`

```solidity
function inviteUsers(uint256 _eventId, address[] memory _invitees) public onlyOwner
```

Invites multiple users to an event.

**Parameters:**

- `_eventId`: The ID of the event.
- `_invitees`: The addresses of the invitees.

**Modifiers:**

- `onlyOwner`

### `acceptInvite`

```solidity
function acceptInvite(uint256 _eventId) public
```

Allows an invited user to accept the invitation and join the event.

**Parameters:**

- `_eventId`: The ID of the event.

**Requirements:**

- The caller must be invited.
- The current timestamp must be before the registration deadline.

**Emits:**

- `UserAccepted(uint256 eventId, address participant)`

### `checkArrivals`

```solidity
function checkArrivals(uint256 _eventId) public
```

Checks whether participants arrived on time for the event and applies penalties if necessary.

**Parameters:**

- `_eventId`: The ID of the event.

**Emits:**

- `UserCheckedArrival(uint256 eventId, address participant, bool onTime)`

### `validateArrival`

```solidity
function validateArrival(uint256 _eventId, address _participant) internal view returns (bool)
```

Validates the arrival of a participant.

**Parameters:**

- `_eventId`: The ID of the event.
- `_participant`: The address of the participant.

**Returns:**

- `bool`: Whether the participant arrived on time.

### `validateArrivalMock`

```solidity
function validateArrivalMock(uint256 _eventId, address _participant) public view returns (bool)
```

Mocks the validation of a participant's arrival.

**Parameters:**

- `_eventId`: The ID of the event.
- `_participant`: The address of the participant.

**Returns:**

- `bool`: Mock validation status.

### `mockValidationTrue`

```solidity
function mockValidationTrue(uint256 _eventId, address _participant) public
```

Mocks setting a participant's validation status to true.

**Parameters:**

- `_eventId`: The ID of the event.
- `_participant`: The address of the participant.

### `handlePenalty`

```solidity
function _handlePenalty(uint256 _eventId, address _participant) internal
```

Handles the distribution of penalties to participants who did not arrive on time.

**Parameters:**

- `_eventId`: The ID of the event.
- `_participant`: The address of the participant.

### `getUserJoinedEvents`

```solidity
function getUserJoinedEvents(address _user) public view returns (uint256[] memory)
```

Returns a list of event IDs that the user has joined.

**Parameters:**

- `_user`: The address of the user.

**Returns:**

- `uint256[]`: An array of event IDs.

### `getUserLateCount`

```solidity
function getUserLateCount(address _user) public view returns (uint256)
```

Returns the number of times a user was late for events.

**Parameters:**

- `_user`: The address of the user.

**Returns:**

- `uint256`: The count of late occurrences.

### `claim`

```solidity
function claim() public
```

Allows a user to claim their claimable amount after an event.

**Requirements:**

- The caller must have a claimable amount.

### `decodeCoordinates`

```solidity
function decodeCoordinates(bytes32 encoded) public pure returns (int256 latitude, int256 longitude)
```

Decodes encoded coordinates.

**Parameters:**

- `encoded`: The encoded coordinates.

**Returns:**

- `latitude`: The latitude as `int256`.
- `longitude`: The longitude as `int256`.

### `encodeCoordinates`

```solidity
function encodeCoordinates(int256 latitude, int256 longitude) public pure returns (bytes32)
```

Encodes coordinates.

**Parameters:**

- `latitude`: The latitude as `int256`.
- `longitude`: The longitude as `int256`.

**Returns:**

- `bytes32`: The encoded coordinates.

## Events

### `EventCreated`

```solidity
event EventCreated(uint256 eventId, string name, uint256 regDeadline, uint256 arrivalTime, bytes32 location)
```

Emitted when a new event is created.

**Parameters:**

- `eventId`: The ID of the event.
- `name`: The name of the event.
- `regDeadline`: The registration deadline.
- `arrivalTime`: The scheduled arrival time.
- `location`: The encoded location of the event.

### `UserInvited`

```solidity
event UserInvited(uint256 eventId, address invitee)
```

Emitted when a user is invited to an event.

**Parameters:**

- `eventId`: The ID of the event.
- `invitee`: The address of the invited user.

### `UserAccepted`

```solidity
event UserAccepted(uint256 eventId, address participant)
```

Emitted when an invited user accepts the invitation and joins the event.

**Parameters:**

- `eventId`: The ID of the event.
- `participant`: The address of the participant.

### `UserCheckedArrival`

```solidity
event UserCheckedArrival(uint256 eventId, address participant, bool onTime)
```

Emitted when a participant's arrival is checked and validated.

**Parameters:**

- `eventId`: The ID of the event.
- `participant`: The address of the participant.
- `onTime`: Whether the participant arrived on time.

### `Claimed`

```solidity
event Claimed(address user, uint256 amount)
```

Emitted when a user claims their claimable amount.

**Parameters:**

- `user`: The address of the user.
- `amount`: The amount claimed.
