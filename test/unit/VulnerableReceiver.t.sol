// SPDX-License-Identifier: MIT
pragma solidity ^0.8.34;

import {Test} from "forge-std/Test.sol";
import {VulnerableReceiver} from "../../src/VulnerableReceiver.sol";

contract VulnerableReceiverTest is Test {
    VulnerableReceiver internal receiver;

    address internal constant DISPATCHER = address(0xD15);
    address internal constant SOURCE_SENDER = address(0xBEEF);

    uint256 internal constant SOURCE_CHAIN_ID = 1;

    bytes32 internal constant MESSAGE_ID = keccak256("message-0");
    bytes32 internal constant PAYLOAD_HASH = keccak256("payload-0");

    function setUp() public {
        receiver = new VulnerableReceiver(DISPATCHER, SOURCE_CHAIN_ID, SOURCE_SENDER);
    }

    function test_ValidMessageExecutes() public {
        vm.prank(DISPATCHER);

        receiver.receiveMessage(MESSAGE_ID, SOURCE_CHAIN_ID, SOURCE_SENDER, 0, PAYLOAD_HASH);

        assertEq(receiver.executionCount(), 1);
        assertEq(receiver.lastPayloadHash(), PAYLOAD_HASH);
    }

    function test_ReplayExecutesSameMessageTwice() public {
        vm.startPrank(DISPATCHER);

        receiver.receiveMessage(MESSAGE_ID, SOURCE_CHAIN_ID, SOURCE_SENDER, 0, PAYLOAD_HASH);

        receiver.receiveMessage(MESSAGE_ID, SOURCE_CHAIN_ID, SOURCE_SENDER, 0, PAYLOAD_HASH);

        vm.stopPrank();

        assertEq(receiver.executionCount(), 2);
    }

    function test_SameNonceWithDifferentMessageIdExecutesTwice() public {
        bytes32 secondMessageId = keccak256("message-1");

        vm.startPrank(DISPATCHER);

        receiver.receiveMessage(MESSAGE_ID, SOURCE_CHAIN_ID, SOURCE_SENDER, 0, PAYLOAD_HASH);

        receiver.receiveMessage(secondMessageId, SOURCE_CHAIN_ID, SOURCE_SENDER, 0, PAYLOAD_HASH);

        vm.stopPrank();

        assertEq(receiver.executionCount(), 2);
    }

    function test_RevertWhen_UnauthorizedDispatcher() public {
        vm.expectRevert(VulnerableReceiver.UnauthorizedDispatcher.selector);

        receiver.receiveMessage(MESSAGE_ID, SOURCE_CHAIN_ID, SOURCE_SENDER, 0, PAYLOAD_HASH);
    }

    function test_RevertWhen_InvalidSourceChain() public {
        vm.prank(DISPATCHER);

        vm.expectRevert(VulnerableReceiver.InvalidSourceChain.selector);

        receiver.receiveMessage(MESSAGE_ID, SOURCE_CHAIN_ID + 1, SOURCE_SENDER, 0, PAYLOAD_HASH);
    }

    function test_RevertWhen_InvalidSourceSender() public {
        vm.prank(DISPATCHER);

        vm.expectRevert(VulnerableReceiver.InvalidSourceSender.selector);

        receiver.receiveMessage(MESSAGE_ID, SOURCE_CHAIN_ID, address(0xCAFE), 0, PAYLOAD_HASH);
    }
}
