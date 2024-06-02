// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FunctionsClient } from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import { ConfirmedOwner } from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import { FunctionsRequest } from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

contract FunctionsConsumerDecoder is FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;

    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;

    mapping(uint256 => mapping(address => bool)) public validationStatus; // Mapping to store validation status

    event Response(bytes32 indexed requestId, bytes response, bytes err);
    event DecodedResponse(bytes32 indexed requestId, bool isValid);

    constructor(address router) FunctionsClient(router) ConfirmedOwner(msg.sender) {}

    function sendRequest(
        string memory source,
        bytes memory encryptedSecretsUrls,
        uint8 donHostedSecretsSlotID,
        uint64 donHostedSecretsVersion,
        string[] memory args,
        bytes[] memory bytesArgs,
        uint64 subscriptionId,
        uint32 gasLimit,
        bytes32 donID
    ) external onlyOwner returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source);
        if (encryptedSecretsUrls.length > 0) req.addSecretsReference(encryptedSecretsUrls);
        else if (donHostedSecretsVersion > 0) {
            req.addDONHostedSecrets(donHostedSecretsSlotID, donHostedSecretsVersion);
        }
        if (args.length > 0) req.setArgs(args);
        if (bytesArgs.length > 0) req.setBytesArgs(bytesArgs);
        s_lastRequestId = _sendRequest(req.encodeCBOR(), subscriptionId, gasLimit, donID);
        return s_lastRequestId;
    }

    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        require(s_lastRequestId == requestId, "Invalid request ID");

        s_lastError = err;
        s_lastResponse = response;

        if (response.length > 0) {
            (uint256 eventId, address participant, bool isValid) = abi.decode(response, (uint256, address, bool));
            validationStatus[eventId][participant] = isValid;
            emit DecodedResponse(requestId, isValid);
        }

        emit Response(requestId, response, err);
    }
}
