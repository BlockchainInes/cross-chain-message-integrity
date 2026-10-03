// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {CrossChainReceiver} from "../../src/CrossChainReceiver.sol";

contract MessageHandler is Test {
    CrossChainReceiver public immutable receiver;

    address public immutable dispatcher;
    address public immutable sourceSender;
    uint256 public immutable sourceChainId;

    uint256 public successfulExecutions;
    uint256 public rejectedExecutions;

    mapping(bytes32 => uint256) public successfulExecutionsByMessageId;

    bytes32[] internal attemptedMessageIds;

    constructor(CrossChainReceiver receiver_, address dispatcher_, uint256 sourceChainId_, address sourceSender_) {
        receiver = receiver_;
        dispatcher = dispatcher_;
        sourceChainId = sourceChainId_;
        sourceSender = sourceSender_;
    }

    function executeValid(uint256 seed) external {
        uint64 nonce = receiver.nextNonce(sourceChainId, sourceSender);
        bytes32 messageId = keccak256(abi.encode("valid", nonce, seed));
        bytes32 payloadHash = keccak256(abi.encode("payload", nonce, seed));

        _attempt(dispatcher, messageId, sourceChainId, sourceSender, nonce, payloadHash);
    }

    function replay(uint256 indexSeed) external {
        uint256 length = attemptedMessageIds.length;
        if (length == 0) return;

        bytes32 messageId = attemptedMessageIds[indexSeed % length];
        uint64 nonce = receiver.nextNonce(sourceChainId, sourceSender);

        if (nonce > 0) {
            unchecked {
                nonce -= 1;
            }
        }

        _attempt(dispatcher, messageId, sourceChainId, sourceSender, nonce, keccak256(abi.encode("replay", indexSeed)));
    }

    function executeOldNonce(uint256 seed) external {
        uint64 currentNonce = receiver.nextNonce(sourceChainId, sourceSender);

        if (currentNonce == 0) return;

        uint64 oldNonce;
        unchecked {
            oldNonce = currentNonce - 1;
        }

        _attempt(
            dispatcher,
            keccak256(abi.encode("old-nonce", seed, currentNonce)),
            sourceChainId,
            sourceSender,
            oldNonce,
            keccak256(abi.encode("payload", seed))
        );
    }

    function executeFutureNonce(uint64 jump, uint256 seed) external {
        uint64 currentNonce = receiver.nextNonce(sourceChainId, sourceSender);

        uint64 offset = uint64(bound(uint256(jump), 1, 32));

        if (currentNonce > type(uint64).max - offset) return;

        uint64 futureNonce = currentNonce + offset;

        _attempt(
            dispatcher,
            keccak256(abi.encode("future-nonce", seed, futureNonce)),
            sourceChainId,
            sourceSender,
            futureNonce,
            keccak256(abi.encode("payload", seed))
        );
    }

    function executeWrongSourceChain(uint256 seed) external {
        _attempt(
            dispatcher,
            keccak256(abi.encode("wrong-chain", seed)),
            sourceChainId + 1,
            sourceSender,
            0,
            keccak256(abi.encode("payload", seed))
        );
    }

    function executeWrongSourceSender(address wrongSender, uint256 seed) external {
        if (wrongSender == sourceSender) {
            wrongSender = address(uint160(sourceSender) ^ 1);
        }

        _attempt(
            dispatcher,
            keccak256(abi.encode("wrong-sender", seed)),
            sourceChainId,
            wrongSender,
            0,
            keccak256(abi.encode("payload", seed))
        );
    }

    function executeUnauthorizedCaller(address caller, uint256 seed) external {
        if (caller == dispatcher) {
            caller = address(uint160(dispatcher) ^ 1);
        }

        uint64 nonce = receiver.nextNonce(sourceChainId, sourceSender);

        _attempt(
            caller,
            keccak256(abi.encode("unauthorized", seed, nonce)),
            sourceChainId,
            sourceSender,
            nonce,
            keccak256(abi.encode("payload", seed))
        );
    }

    function attemptedMessageIdsLength() external view returns (uint256) {
        return attemptedMessageIds.length;
    }

    function attemptedMessageId(uint256 index) external view returns (bytes32) {
        return attemptedMessageIds[index];
    }

    function _attempt(
        address caller,
        bytes32 messageId,
        uint256 messageSourceChainId,
        address messageSourceSender,
        uint64 nonce,
        bytes32 payloadHash
    ) internal {
        attemptedMessageIds.push(messageId);

        vm.prank(caller);

        try receiver.receiveMessage(messageId, messageSourceChainId, messageSourceSender, nonce, payloadHash) {
            successfulExecutions += 1;
            successfulExecutionsByMessageId[messageId] += 1;
        } catch {
            rejectedExecutions += 1;
        }
    }
}
