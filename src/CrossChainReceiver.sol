// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

contract CrossChainReceiver {
    error UnauthorizedDispatcher();
    error InvalidSourceChain();
    error InvalidSourceSender();
    error MessageAlreadyProcessed();
    error InvalidNonce(uint64 expected, uint64 received);

    address public immutable dispatcher;
    uint256 public immutable allowedSourceChainId;
    address public immutable allowedSourceSender;

    mapping(bytes32 => bool) public processedMessages;
    mapping(uint256 => mapping(address => uint64)) public nextNonce;

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
        if (processedMessages[messageId]) revert MessageAlreadyProcessed();

        uint64 expectedNonce = nextNonce[sourceChainId][sourceSender];
        if (nonce != expectedNonce) {
            revert InvalidNonce(expectedNonce, nonce);
        }

        processedMessages[messageId] = true;
        nextNonce[sourceChainId][sourceSender] = expectedNonce + 1;

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