// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract EventContract {
    struct Event {
        uint256 eventId;
        address creator;
        uint256 eventDate;
        uint256 deposit;
        mapping(address => bool) participants;
        address[] participantList;
        bool finalized;
    }

    uint256 public eventCount = 0;
    mapping(uint256 => Event) public events;

    event EventCreated(
        uint256 eventId,
        address creator,
        uint256 eventDate,
        uint256 deposit
    );
    event JoinedEvent(uint256 eventId, address participant);
    event CheckedArrival(uint256 eventId, address participant, bool arrived);

    function createEvent(uint256 _eventDate, uint256 _deposit) public {
        eventCount++;
        Event storage newEvent = events[eventCount];
        newEvent.eventId = eventCount;
        newEvent.creator = msg.sender;
        newEvent.eventDate = _eventDate;
        newEvent.deposit = _deposit;
        newEvent.finalized = false;

        emit EventCreated(eventCount, msg.sender, _eventDate, _deposit);
    }

    //@todo
    function invite(address _invitee) public {
        // This function should be called by the creator
        // This function should add the invitee to the participant list while allow the invitee to join/reject the event
        // This function should emit an event
    }

    function joinEvent(uint256 _eventId) public payable {
        //@todo validation for the event

        Event storage myEvent = events[_eventId];
        require(msg.value == myEvent.deposit, "Incorrect deposit amount");
        require(!myEvent.participants[msg.sender], "Already joined");

        myEvent.participants[msg.sender] = true;
        myEvent.participantList.push(msg.sender);

        emit JoinedEvent(_eventId, msg.sender);
    }

    //@todo the arrive boolean should be checked by an oracle
    function checkArrival(uint256 _eventId, address _participant) public {
        // This function should be called by an oracle
        Event storage myEvent = events[_eventId];
        require(myEvent.participants[_participant], "Not a participant");
        require(block.timestamp >= myEvent.eventDate, "Event date not reached");
        require(!myEvent.finalized, "Event already finalized");

        bool _arrived = validateArrival(_eventId, _participant);

        if (!_arrived) {
            uint256 share = myEvent.deposit /
                (myEvent.participantList.length - 1);
            for (uint256 i = 0; i < myEvent.participantList.length; i++) {
                if (myEvent.participantList[i] != _participant) {
                    payable(myEvent.participantList[i]).transfer(share);
                }
            }
        } else {
            payable(_participant).transfer(myEvent.deposit);
        }

        //@todo edit finailise logic
        myEvent.finalized = true;

        emit CheckedArrival(_eventId, _participant, _arrived);
    }

    //@todo

    function validateArrival(
        uint256 _eventId,
        address _participant
    ) public view returns (bool) {
        // This function should be called by an oracle
        // This function should return a boolean value
        return true;
    }
}
