// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

contract VulnerableReceiver {
    error UnauthorizedDispatcher();
    error InvalidSourceChain();
    error InvalidSourceSender();

    address public immutable dispatcher;
    uint256 public immutable allowedSourceChainId;
    address public immutable allowedSourceSender;

    uint256 public executionCount;
    bytes32 public lastPayloadHash;

    event MessageExecuted(
        bytes32 indexed messageId,
        uint256 indexed sourceChainId,
        address indexed sourceSender,
        uint64 nonce,
        bytes32 payloadHash
    );

    constructor(
        address dispatcher_,
        uint256 allowedSourceChainId_,
        address allowedSourceSender_
    ) {
        dispatcher = dispatcher_;
        allowedSourceChainId = allowedSourceChainId_;
        allowedSourceSender = allowedSourceSender_;
    }

    function receiveMessage(
        bytes32 messageId,
        uint256 sourceChainId,
        address sourceSender,
        uint64 nonce,
        bytes32 payloadHash
    ) external {
        if (msg.sender != dispatcher) revert UnauthorizedDispatcher();
        if (sourceChainId != allowedSourceChainId) revert InvalidSourceChain();
        if (sourceSender != allowedSourceSender) revert InvalidSourceSender();

        executionCount += 1;
        lastPayloadHash = payloadHash;

        emit MessageExecuted(
            messageId,
            sourceChainId,
            sourceSender,
            nonce,
            payloadHash
        );
    }
}