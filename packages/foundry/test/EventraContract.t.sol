// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { EventraContract } from "../contracts/EventraContract.sol";

contract EventraTests is Test {
    EventraContract internal eventra;
    address internal owner = makeAddr("owner");
    address internal buyer = makeAddr("buyer");
    address internal buyer2 = makeAddr("buyer2");

    address internal eventCompany = makeAddr("eventCompany");
    address internal eventCompany2 = makeAddr("eventCompany2");

    event EventCreated(uint256 indexed eventId, string indexed eventName, uint96 ticketPrice, uint48 indexed eventDate);

    error InvalidArgument(string argument);
    error InvalidAmount(uint256 sent, uint256 required);
    error TicketNotFound();
    error EventNotFound(uint256 eventId);
    error InvalidEventState();
    error InvalidTicketState();
    error SalesClosed();
    error Unauthorized(string argument);
    error PayoutNotActiveYet();
    error PayoutAlreadyPaid();
    error InvalidAddress();
    error NotValidPayout();
    error TransferFailed(address to, uint256 amount);

    string internal testEventName = "TEST";
    string internal testEventDescription = "TEST DESCRIPTION";
    uint96 internal testTicketPrice = 0.1 ether;
    uint48 internal testStartSellDate = uint48(block.timestamp + 1 days);
    uint48 internal testEndSellDate = uint48(block.timestamp + 7 days);
    uint48 internal testEventDate = uint48(block.timestamp + 14 days);
    uint16 internal testTicketRoyalty = 15;
    uint32 internal testTotalTicketNumber = 100;

    function setUp() public {
        eventra = new EventraContract(owner);

        vm.deal(buyer, 10 ether);
        vm.deal(eventCompany, 10 ether);
        vm.deal(address(eventra), 100 ether);
    }

    function test_createEventHappyPath() public {
        //IMPORTANTE SE HA MODIFICADO EL FOUNDRY.TOML CON via_ir = true PARA DESHABILITAR EL FALLO DE "STACK TOO DEEP"

        vm.expectEmit(true, true, false, true);
        emit EventCreated(1, testEventName, testTicketPrice, testEventDate);

        vm.prank(eventCompany);
        eventra.createEvent{ value: 1 ether }(
            testEventName,
            testEventDescription,
            testTicketPrice,
            testStartSellDate,
            testEndSellDate,
            testEventDate,
            testTicketRoyalty,
            testTotalTicketNumber
        );

        (
            string memory eventName,
            string memory eventDescription,
            uint96 ticketPrice,
            uint48 startSellDate,
            uint48 endSellDate,
            uint48 eventDate,
            uint16 ticketRoyalty,
            uint32 totalTicketNumber,
            uint256 eventId,
            address organizer,
            uint256 eventFunds,
            EventraContract.EventState eventState
        ) = eventra.events(1);

        assertEq(testEventName, eventName);
        assertEq(testEventDescription, eventDescription);
        assertEq(testTicketPrice, ticketPrice);
        assertEq(testStartSellDate, startSellDate);
        assertEq(testEndSellDate, endSellDate);
        assertEq(testEventDate, eventDate);
        assertEq(testTicketRoyalty, ticketRoyalty);
        assertEq(testTotalTicketNumber, totalTicketNumber);
        assertGt(eventId, 0);
        assertEq(eventCompany, organizer);
        assertEq(eventFunds, 0); //SERA CAMBIADO
        assertEq(uint256(eventState), uint256(EventraContract.EventState.Active));
    }

    function test_createEventWrongDeposit() public {
        vm.prank(eventCompany);
        vm.expectPartialRevert(InvalidAmount.selector);

        eventra.createEvent{ value: 0.1 ether }(
            testEventName,
            testEventDescription,
            testTicketPrice,
            testStartSellDate,
            testEndSellDate,
            testEventDate,
            testTicketRoyalty,
            testTotalTicketNumber
        );
    }

    function test_createEventWrongName() public {
        vm.prank(eventCompany);
        vm.expectPartialRevert(InvalidArgument.selector);

        eventra.createEvent{ value: 1 ether }(
            "",
            testEventDescription,
            testTicketPrice,
            testStartSellDate,
            testEndSellDate,
            testEventDate,
            testTicketRoyalty,
            testTotalTicketNumber
        );
    }

    function test_createEventWrongDescription() public {
        vm.prank(eventCompany);
        vm.expectPartialRevert(InvalidArgument.selector);

        eventra.createEvent{ value: 1 ether }(
            testEventName,
            "",
            testTicketPrice,
            testStartSellDate,
            testEndSellDate,
            testEventDate,
            testTicketRoyalty,
            testTotalTicketNumber
        );
    }

    function test_createEventWrongTicketPrice() public {
        vm.prank(eventCompany);
        vm.expectPartialRevert(InvalidArgument.selector);

        eventra.createEvent{ value: 1 ether }(
            testEventName,
            testEventDescription,
            0,
            testStartSellDate,
            testEndSellDate,
            testEventDate,
            testTicketRoyalty,
            testTotalTicketNumber
        );
    }

    function test_createEventWrongStartSellDate() public {
        vm.prank(eventCompany);
        vm.expectPartialRevert(InvalidArgument.selector);

        eventra.createEvent{ value: 1 ether }(
            testEventName,
            testEventDescription,
            testTicketPrice,
            uint48(block.timestamp),
            testEndSellDate,
            testEventDate,
            testTicketRoyalty,
            testTotalTicketNumber
        );
    }

    function test_createEventWrongEndSellDate() public {
        vm.prank(eventCompany);
        vm.expectPartialRevert(InvalidArgument.selector);

        eventra.createEvent{ value: 1 ether }(
            testEventName,
            testEventDescription,
            testTicketPrice,
            testStartSellDate,
            uint48(block.timestamp),
            testEventDate,
            testTicketRoyalty,
            testTotalTicketNumber
        );
    }

    function test_createEventWrongEventDate() public {
        vm.prank(eventCompany);
        vm.expectPartialRevert(InvalidArgument.selector);

        eventra.createEvent{ value: 1 ether }(
            testEventName,
            testEventDescription,
            testTicketPrice,
            testStartSellDate,
            testEndSellDate,
            uint48(block.timestamp),
            testTicketRoyalty,
            testTotalTicketNumber
        );
    }

    function test_createEventRoyaltyBelowMinimum() public {
        vm.prank(eventCompany);
        vm.expectPartialRevert(InvalidArgument.selector);

        eventra.createEvent{ value: 1 ether }(
            testEventName,
            testEventDescription,
            testTicketPrice,
            testStartSellDate,
            testEndSellDate,
            testEventDate,
            9,
            testTotalTicketNumber
        );
    }

    function test_createEventRoyaltyAboveMaximum() public {
        vm.prank(eventCompany);
        vm.expectPartialRevert(InvalidArgument.selector);

        eventra.createEvent{ value: 1 ether }(
            testEventName,
            testEventDescription,
            testTicketPrice,
            testStartSellDate,
            testEndSellDate,
            testEventDate,
            26,
            testTotalTicketNumber
        );
    }

    function test_createEventWrongTotalTicketNumber() public {
        vm.prank(eventCompany);
        vm.expectPartialRevert(InvalidArgument.selector);

        eventra.createEvent{ value: 1 ether }(
            testEventName,
            testEventDescription,
            testTicketPrice,
            testStartSellDate,
            testEndSellDate,
            testEventDate,
            testTicketRoyalty,
            0
        );
    }

    function test_viewStatisticsWrongOrganizer() public {
        vm.prank(eventCompany);
        eventra.createEvent{ value: 1 ether }(
            testEventName,
            testEventDescription,
            testTicketPrice,
            testStartSellDate,
            testEndSellDate,
            testEventDate,
            testTicketRoyalty,
            testTotalTicketNumber
        );
        vm.stopPrank();

        vm.prank(eventCompany2);

        vm.expectPartialRevert(Unauthorized.selector);
        eventra.viewStatistics(1);
    }

    function test_viewStatisticsWrongEvent() public {
        vm.prank(eventCompany);
        vm.expectPartialRevert(EventNotFound.selector);
        eventra.viewStatistics(100);
    }
}
