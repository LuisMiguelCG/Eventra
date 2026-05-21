// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { EventraContract } from "../contracts/EventraContract.sol";

contract EventraTests is Test {
    EventraContract internal eventra;
    address internal owner = makeAddr("owner");
    address internal buyer = makeAddr("buyer");
    address internal buyer2 = makeAddr("buyer2");
    address internal buyer3 = makeAddr("buyer3");

    address internal eventCompany = makeAddr("eventCompany");
    address internal eventCompany2 = makeAddr("eventCompany2");

    event EventCreated(uint256 indexed eventId, string indexed eventName, uint96 ticketPrice, uint48 indexed eventDate);
    event TicketSold(uint256 indexed eventId, uint256 indexed tokenId, address indexed buyer, uint96 price);

    error InvalidArgument(string argument);
    error InvalidAmount(uint256 sent, uint256 required);
    error TicketNotFound();
    error EventNotFound(uint256 eventId);
    error InvalidEventState();
    error InvalidTicketState();
    error SalesClosed(uint256 eventId);
    error Unauthorized(string argument);
    error PayoutNotActiveYet();
    error PayoutAlreadyPaid();
    error InvalidAddress();
    error NotValidPayout();
    error TransferFailed(address to, uint256 amount);
    error NotFundsToWithdraw(address organizer, uint256 eventId);
    error EventNotFinished(uint256 eventId);
    error EventFinished(uint256 eventId);
    error EventNotActive(uint256 eventId);
    error EventIsSoldOut(uint256 eventId);
    error EventCancelled(uint256 eventId);

    string internal testCompanyName = "TEST COMPANY NAME";
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
        vm.deal(buyer2, 10 ether);
        vm.deal(buyer3, 10 ether);

        vm.deal(eventCompany, 10 ether);
        vm.deal(address(eventra), 100 ether);
    }

    /// Helpers ///

    function _registerAndCreateDefaultEvent() internal {
        eventra.registerCompany(testCompanyName, eventCompany);

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
    }

    /// Tests Create Event ///

    function test_createEventHappyPath() public {
        //IMPORTANTE SE HA MODIFICADO EL FOUNDRY.TOML CON via_ir = true PARA DESHABILITAR EL FALLO DE "STACK TOO DEEP"

        eventra.registerCompany(testCompanyName, eventCompany);
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
            uint32 ticketsSold,
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
        assertEq(eventFunds, 0);
        assertEq(ticketsSold, 0);
        assertEq(uint256(eventState), uint256(EventraContract.EventState.Active));
    }

    function test_createEventWrongDeposit() public {
        eventra.registerCompany(testCompanyName, eventCompany);

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
        eventra.registerCompany(testCompanyName, eventCompany);

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
        eventra.registerCompany(testCompanyName, eventCompany);

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
        eventra.registerCompany(testCompanyName, eventCompany);

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
        eventra.registerCompany(testCompanyName, eventCompany);

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
        eventra.registerCompany(testCompanyName, eventCompany);

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
        eventra.registerCompany(testCompanyName, eventCompany);

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
        eventra.registerCompany(testCompanyName, eventCompany);

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
        eventra.registerCompany(testCompanyName, eventCompany);

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
        eventra.registerCompany(testCompanyName, eventCompany);

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

    /// Tests View Statistics ///

    function test_viewStatisticsWrongOrganizer() public {
        _registerAndCreateDefaultEvent();

        vm.prank(eventCompany2);

        vm.expectPartialRevert(Unauthorized.selector);
        eventra.viewStatistics(1);
    }

    function test_viewStatisticsWrongEvent() public {
        eventra.registerCompany(testCompanyName, eventCompany);

        vm.prank(eventCompany);
        vm.expectPartialRevert(EventNotFound.selector);
        eventra.viewStatistics(100);
    }

    /// Tests Buy Tickets ///

    function test_buyTicketHappyPath() public {
        _registerAndCreateDefaultEvent();

        vm.expectEmit(true, true, false, true);
        emit TicketSold(1, 1, buyer, testTicketPrice);
        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: testTicketPrice }(1);

        assertEq(eventra.eventTickets(1, 0), 1);

        assertEq(eventra.userTickets(buyer, 0), 1);

        (,,,,,,,,,,, uint32 ticketsSold,) = eventra.events(1);
        assertEq(ticketsSold, 1);

        (,,,,,,,,,, uint256 eventFunds,,) = eventra.events(1);

        assertEq(eventFunds, 0.1 ether);

        (uint256 ticketEventId, address ticketUser, EventraContract.TicketState ticketState) = eventra.tickets(1);
        assertEq(ticketEventId, 1);
        assertEq(ticketUser, buyer);
        assertEq(uint256(ticketState), uint256(EventraContract.TicketState.Active));

        assertEq(eventra.nextTokenId(), 2);
    }

    function test_buyTicketWrongAmountLess() public {
        _registerAndCreateDefaultEvent();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        vm.expectPartialRevert(InvalidAmount.selector);
        eventra.buyTicket{ value: testTicketPrice - 1 wei }(1);
    }

    function test_buyTicketWrongAmountMore() public {
        _registerAndCreateDefaultEvent();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        vm.expectPartialRevert(InvalidAmount.selector);
        eventra.buyTicket{ value: testTicketPrice + 1 wei }(1);
    }

    function test_buyTicketWrongEventId() public {
        vm.warp(testStartSellDate);
        vm.prank(buyer);
        vm.expectPartialRevert(EventNotFound.selector);
        eventra.buyTicket{ value: testTicketPrice }(100);
    }

    function test_buyTicketSalesClosed() public {
        _registerAndCreateDefaultEvent();

        vm.warp(block.timestamp);
        vm.prank(buyer);
        vm.expectPartialRevert(SalesClosed.selector);
        eventra.buyTicket{ value: testTicketPrice }(1);
    }

    function test_buyTicketSoldOut() public {
        eventra.registerCompany(testCompanyName, eventCompany);

        vm.prank(eventCompany);
        eventra.createEvent{ value: 1 ether }(
            testEventName,
            testEventDescription,
            testTicketPrice,
            testStartSellDate,
            testEndSellDate,
            testEventDate,
            testTicketRoyalty,
            2
        );
        vm.stopPrank();
        vm.warp(testEndSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: testTicketPrice }(1);
        vm.stopPrank();

        vm.prank(buyer2);
        eventra.buyTicket{ value: testTicketPrice }(1);
        vm.stopPrank();

        vm.prank(buyer3);
        vm.expectPartialRevert(EventIsSoldOut.selector);
        eventra.buyTicket{ value: testTicketPrice }(1);
    }

    function test_buyTicketAfterEndSellDate() public {
        _registerAndCreateDefaultEvent();

        vm.warp(testEndSellDate + 1);
        vm.prank(buyer);
        vm.expectPartialRevert(SalesClosed.selector);
        eventra.buyTicket(1);
    }

    function test_buyTicketEventFinished() public {
        _registerAndCreateDefaultEvent();
        vm.warp(testEventDate);
        vm.prank(buyer);
        vm.expectPartialRevert(EventFinished.selector);
        eventra.buyTicket{ value: testTicketPrice }(1);

        /// Tests Buy Ticket pendientes de implementar ///

        // - test_buyTicketEventCancelled: el organizador cancela el evento y luego se intenta comprar -> EventCancelled.
        // - test_buyTicketMintsNFTToBuyer: comprobar eventra.ownerOf(1) == buyer y eventra.balanceOf(buyer) == 1.
        // - test_buyTicketMultipleBuyersTokenIds: dos compradores -> tokenIds 1 y 2, userTickets y eventTickets correctos para cada uno, ticketsSold == 2, eventFunds == 2 * price.
    }
}
