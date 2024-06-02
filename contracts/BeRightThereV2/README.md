# BeRightThereV2 Smart Contract

## Overview

`BeRightThereV2` is an advanced smart contract designed for event organizers to manage participants. It incorporates Chainlink Automation and Chainlink Functions to handle event validations and automation seamlessly. This contract enables organizers to invite users, enforce penalties for late arrivals, and manage user deposits, leveraging Chainlink's decentralized services.

## Installation

To deploy this project, install all dependencies:

```sh
npm install
```

## Contract Functions

### `initialize`

```solidity
function initialize(address _token) public initializer
```

Initializes the contract with the token address and sets the contract owner. This function is called only once during deployment.

**Modifiers:**

- `initializer`

### `setChainlinkConfig`

```solidity
function setChainlinkConfig(address _chainlinkKeeper, address _functionsConsumer) public onlyOwner
```

Sets the Chainlink keeper and functions consumer addresses.

**Parameters:**

- `_chainlinkKeeper`: The address of the Chainlink keeper.
- `_functionsConsumer`: The address of the functions consumer.

**Modifiers:**

- `onlyOwner`

**Emits:**

- `ChainlinkKeeperSet(address chainlinkKeeper, address functionsConsumer)`

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
) public
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

Checks whether participants arrived on time for the event and triggers validation through Chainlink Functions.

**Parameters:**

- `_eventId`: The ID of the event.

### `checkUpkeep`

```solidity
function checkUpkeep(bytes calldata data) external view override returns (bool upkeepNeeded, bytes memory performData)
```

Checks if upkeep is needed.

**Parameters:**

- `data`: The data to check.

**Returns:**

- `upkeepNeeded`: A boolean indicating if upkeep is needed.
- `performData`: The data to perform the upkeep.

### `performUpkeep`

```solidity
function performUpkeep(bytes calldata performData) external override
```

Performs the upkeep.

**Parameters:**

- `performData`: The data to perform the upkeep.

### `processValidationResponse`

```solidity
function processValidationResponse(uint256 eventId) public
```

Processes the validation response for an event.

**Parameters:**

- `eventId`: The ID of the event.

### `distributeRewards`

```solidity
function distributeRewards(uint256 eventId) internal
```

Distributes rewards to participants who arrived on time.

**Parameters:**

- `eventId`: The ID of the event.

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

### `claim`

```solidity
function claim() public
```

Allows a user to claim their claimable amount after an event.

**Requirements:**

- The caller must have a claimable amount.

**Emits:**

- `Claimed(address user, uint256 amount)`

### Helper Functions

### `uint2str`

```solidity
function uint2str(uint256 _i) internal pure returns (string memory)
```

Converts a `uint256` to a `string`.

**Parameters:**

- `_i`: The `uint256` value to convert.

**Returns:**

- `string`: The string representation of the `uint256` value.

### `addressToString`

```solidity
function addressToString(address _addr) internal pure returns (string memory)
```

Converts an address to a string.

**Parameters:**

- `_addr`: The address to convert.

**Returns:**

- `string`: The string representation of the address.

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
