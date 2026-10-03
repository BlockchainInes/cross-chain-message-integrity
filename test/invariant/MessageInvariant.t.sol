// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";

import {CrossChainReceiver} from "../../src/CrossChainReceiver.sol";
import {MessageHandler} from "./MessageHandler.sol";

contract MessageInvariantTest is StdInvariant, Test {
    CrossChainReceiver internal receiver;
    MessageHandler internal handler;

    address internal constant DISPATCHER = address(0xD15);
    address internal constant SOURCE_SENDER = address(0xBEEF);

    uint256 internal constant SOURCE_CHAIN_ID = 1;

    function setUp() public {
        receiver = new CrossChainReceiver(
            DISPATCHER,
            SOURCE_CHAIN_ID,
            SOURCE_SENDER
        );

        handler = new MessageHandler(
            receiver,
            DISPATCHER,
            SOURCE_CHAIN_ID,
            SOURCE_SENDER
        );

        targetContract(address(handler));
    }

    function invariant_ExecutionCountMatchesSuccessfulExecutions()
        public
        view
    {
        assertEq(
            receiver.executionCount(),
            handler.successfulExecutions()
        );
    }

    function invariant_NonceTracksSuccessfulExecutions()
        public
        view
    {
        assertEq(
            uint256(
                receiver.nextNonce(
                    SOURCE_CHAIN_ID,
                    SOURCE_SENDER
                )
            ),
            handler.successfulExecutions()
        );
    }

    function invariant_NoMessageExecutesMoreThanOnce()
        public
        view
    {
        uint256 length = handler.attemptedMessageIdsLength();

        for (uint256 i; i < length; ++i) {
            bytes32 messageId = handler.attemptedMessageId(i);

            assertLe(
                handler.successfulExecutionsByMessageId(messageId),
                1
            );
        }
    }

    function invariant_ProcessedMessagesMatchSuccessfulExecution()
        public
        view
    {
        uint256 length = handler.attemptedMessageIdsLength();

        for (uint256 i; i < length; ++i) {
            bytes32 messageId = handler.attemptedMessageId(i);

            uint256 successfulExecutionsForMessage =
                handler.successfulExecutionsByMessageId(messageId);

            assertEq(
                receiver.processedMessages(messageId),
                successfulExecutionsForMessage == 1
            );
        }
    }
}