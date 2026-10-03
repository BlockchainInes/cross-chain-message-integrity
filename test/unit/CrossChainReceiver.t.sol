// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {CrossChainReceiver} from "../../src/CrossChainReceiver.sol";

contract CrossChainReceiverTest is Test {
    CrossChainReceiver internal receiver;

    address internal constant DISPATCHER = address(0xD15);
    address internal constant SOURCE_SENDER = address(0xBEEF);
    address internal constant ATTACKER = address(0xBAD);

    uint256 internal constant SOURCE_CHAIN_ID = 1;

    bytes32 internal constant MESSAGE_ID_0 = keccak256("message-0");
    bytes32 internal constant MESSAGE_ID_1 = keccak256("message-1");
    bytes32 internal constant PAYLOAD_HASH_0 = keccak256("payload-0");
    bytes32 internal constant PAYLOAD_HASH_1 = keccak256("payload-1");

    function setUp() public {
        receiver = new CrossChainReceiver(DISPATCHER, SOURCE_CHAIN_ID, SOURCE_SENDER);
    }

    function test_ReceiveMessage() public {
        vm.prank(DISPATCHER);

        receiver.receiveMessage(MESSAGE_ID_0, SOURCE_CHAIN_ID, SOURCE_SENDER, 0, PAYLOAD_HASH_0);

        assertTrue(receiver.processedMessages(MESSAGE_ID_0));
        assertEq(receiver.nextNonce(SOURCE_CHAIN_ID, SOURCE_SENDER), 1);
        assertEq(receiver.executionCount(), 1);
        assertEq(receiver.lastPayloadHash(), PAYLOAD_HASH_0);
    }

    function test_RevertWhen_UnauthorizedDispatcher() public {
        vm.prank(ATTACKER);
        vm.expectRevert(CrossChainReceiver.UnauthorizedDispatcher.selector);

        receiver.receiveMessage(MESSAGE_ID_0, SOURCE_CHAIN_ID, SOURCE_SENDER, 0, PAYLOAD_HASH_0);
    }

    function test_RevertWhen_InvalidSourceChain() public {
        vm.prank(DISPATCHER);
        vm.expectRevert(CrossChainReceiver.InvalidSourceChain.selector);

        receiver.receiveMessage(MESSAGE_ID_0, SOURCE_CHAIN_ID + 1, SOURCE_SENDER, 0, PAYLOAD_HASH_0);
    }

    function test_RevertWhen_InvalidSourceSender() public {
        vm.prank(DISPATCHER);
        vm.expectRevert(CrossChainReceiver.InvalidSourceSender.selector);

        receiver.receiveMessage(MESSAGE_ID_0, SOURCE_CHAIN_ID, ATTACKER, 0, PAYLOAD_HASH_0);
    }

    function test_RevertWhen_MessageIsReplayed() public {
        vm.startPrank(DISPATCHER);

        receiver.receiveMessage(MESSAGE_ID_0, SOURCE_CHAIN_ID, SOURCE_SENDER, 0, PAYLOAD_HASH_0);

        vm.expectRevert(CrossChainReceiver.MessageAlreadyProcessed.selector);

        receiver.receiveMessage(MESSAGE_ID_0, SOURCE_CHAIN_ID, SOURCE_SENDER, 0, PAYLOAD_HASH_0);

        vm.stopPrank();

        assertEq(receiver.executionCount(), 1);
    }

    function test_RevertWhen_NonceIsSkipped() public {
        vm.prank(DISPATCHER);

        vm.expectRevert(abi.encodeWithSelector(CrossChainReceiver.InvalidNonce.selector, uint64(0), uint64(1)));

        receiver.receiveMessage(MESSAGE_ID_1, SOURCE_CHAIN_ID, SOURCE_SENDER, 1, PAYLOAD_HASH_1);
    }

    function test_RevertWhen_OldNonceUsesNewMessageId() public {
        vm.startPrank(DISPATCHER);

        receiver.receiveMessage(MESSAGE_ID_0, SOURCE_CHAIN_ID, SOURCE_SENDER, 0, PAYLOAD_HASH_0);

        vm.expectRevert(abi.encodeWithSelector(CrossChainReceiver.InvalidNonce.selector, uint64(1), uint64(0)));

        receiver.receiveMessage(MESSAGE_ID_1, SOURCE_CHAIN_ID, SOURCE_SENDER, 0, PAYLOAD_HASH_1);

        vm.stopPrank();

        assertFalse(receiver.processedMessages(MESSAGE_ID_1));
        assertEq(receiver.executionCount(), 1);
    }

    function test_SequentialMessagesExecuteExactlyOnce() public {
        vm.startPrank(DISPATCHER);

        receiver.receiveMessage(MESSAGE_ID_0, SOURCE_CHAIN_ID, SOURCE_SENDER, 0, PAYLOAD_HASH_0);

        receiver.receiveMessage(MESSAGE_ID_1, SOURCE_CHAIN_ID, SOURCE_SENDER, 1, PAYLOAD_HASH_1);

        vm.stopPrank();

        assertTrue(receiver.processedMessages(MESSAGE_ID_0));
        assertTrue(receiver.processedMessages(MESSAGE_ID_1));
        assertEq(receiver.nextNonce(SOURCE_CHAIN_ID, SOURCE_SENDER), 2);
        assertEq(receiver.executionCount(), 2);
        assertEq(receiver.lastPayloadHash(), PAYLOAD_HASH_1);
    }
}
