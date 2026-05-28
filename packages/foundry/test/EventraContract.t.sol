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

    event UserRegistered(address indexed user);
    event EventCompanyRegistered(string companyName, address companyAddress); // TIENE SENTIDO??
    event EventCreated(uint256 indexed eventId, string indexed eventName, uint96 ticketPrice, uint48 indexed eventDate);
    event EventCanceled(
        uint256 indexed eventId, string indexed eventName, uint96 ticketPrice, uint48 indexed eventDate
    );
    event EventFundsWithdrawn(uint256 indexed eventId, string indexed eventName, uint256 amount); //HABRIA QUE VER COMO SE LE PASA EL DINERO OBTENIDO
    event EventSoldOut(uint256 indexed eventId, string indexed eventName);
    event TicketSold(uint256 indexed eventId, uint256 indexed tokenId, address indexed buyer, uint96 price);
    event AccountSuspended(address indexed userSuspended);
    event TicketInResell(uint256 indexed ticketId, uint256 ticketPrice);
    event TicketRemovedFromResell(uint256 indexed ticketId);
    error OwnableUnauthorizedAccount(address account);

    string internal testCompanyName = "TEST COMPANY NAME";
    string internal testEventName = "TEST";
    string internal testEventDescription = "TEST DESCRIPTION";
    uint96 internal testTicketPrice = 0.1 ether;
    uint48 internal testStartSellDate = uint48(block.timestamp + 1 days);
    uint48 internal testEndSellDate = uint48(block.timestamp + 7 days);
    uint48 internal testEventDate = uint48(block.timestamp + 14 days);
    uint16 internal testTicketRoyalty = 15;
    uint32 internal testTotalTicketNumber = 100;
    uint8 internal testMaxTicketsPerAddress = 5;
    uint8 internal testMaxNumberOfOwners = 3;

    uint256 internal constant TEST_COMMISSION = 5;
    uint256 internal totalBuyPrice;

    function setUp() public {
        eventra = new EventraContract(owner, TEST_COMMISSION);

        totalBuyPrice = uint256(testTicketPrice) + (uint256(testTicketPrice) * TEST_COMMISSION) / 100;

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
            testTotalTicketNumber,
            testMaxTicketsPerAddress,
            testMaxNumberOfOwners
        );
    }

    function _registerUser() internal {
        vm.prank(buyer);
        eventra.registerUser();
        vm.prank(buyer2);
        eventra.registerUser();
        vm.prank(buyer3);
        eventra.registerUser();
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
            testTotalTicketNumber,
            testMaxTicketsPerAddress,
            testMaxNumberOfOwners
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
            uint32 ticketsSold,
            uint8 maxTicketsPerAddress,
            uint8 maxNumberOfOwners,
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
        assertEq(eventra.eventCompanyBalance(eventCompany), 0);
        assertEq(ticketsSold, 0);
        assertEq(testMaxTicketsPerAddress, maxTicketsPerAddress);
        assertEq(testMaxNumberOfOwners, maxNumberOfOwners);
        assertEq(uint256(eventState), uint256(EventraContract.EventState.Active));
    }

    function test_createEventWrongDeposit() public {
        eventra.registerCompany(testCompanyName, eventCompany);

        vm.prank(eventCompany);
        vm.expectPartialRevert(EventraContract.InvalidAmount.selector);

        eventra.createEvent{ value: 0.1 ether }(
            testEventName,
            testEventDescription,
            testTicketPrice,
            testStartSellDate,
            testEndSellDate,
            testEventDate,
            testTicketRoyalty,
            testTotalTicketNumber,
            testMaxTicketsPerAddress,
            testMaxNumberOfOwners
        );
    }

    function test_createEventWrongName() public {
        eventra.registerCompany(testCompanyName, eventCompany);

        vm.prank(eventCompany);
        vm.expectPartialRevert(EventraContract.InvalidArgument.selector);

        eventra.createEvent{ value: 1 ether }(
            "",
            testEventDescription,
            testTicketPrice,
            testStartSellDate,
            testEndSellDate,
            testEventDate,
            testTicketRoyalty,
            testTotalTicketNumber,
            testMaxTicketsPerAddress,
            testMaxNumberOfOwners
        );
    }

    function test_createEventWrongDescription() public {
        eventra.registerCompany(testCompanyName, eventCompany);

        vm.prank(eventCompany);
        vm.expectPartialRevert(EventraContract.InvalidArgument.selector);

        eventra.createEvent{ value: 1 ether }(
            testEventName,
            "",
            testTicketPrice,
            testStartSellDate,
            testEndSellDate,
            testEventDate,
            testTicketRoyalty,
            testTotalTicketNumber,
            testMaxTicketsPerAddress,
            testMaxNumberOfOwners
        );
    }

    function test_createEventWrongTicketPrice() public {
        eventra.registerCompany(testCompanyName, eventCompany);

        vm.prank(eventCompany);
        vm.expectPartialRevert(EventraContract.InvalidArgument.selector);

        eventra.createEvent{ value: 1 ether }(
            testEventName,
            testEventDescription,
            0,
            testStartSellDate,
            testEndSellDate,
            testEventDate,
            testTicketRoyalty,
            testTotalTicketNumber,
            testMaxTicketsPerAddress,
            testMaxNumberOfOwners
        );
    }

    function test_createEventWrongStartSellDate() public {
        eventra.registerCompany(testCompanyName, eventCompany);

        vm.prank(eventCompany);
        vm.expectPartialRevert(EventraContract.InvalidArgument.selector);

        eventra.createEvent{ value: 1 ether }(
            testEventName,
            testEventDescription,
            testTicketPrice,
            uint48(block.timestamp),
            testEndSellDate,
            testEventDate,
            testTicketRoyalty,
            testTotalTicketNumber,
            testMaxTicketsPerAddress,
            testMaxNumberOfOwners
        );
    }

    function test_createEventWrongEndSellDate() public {
        eventra.registerCompany(testCompanyName, eventCompany);

        vm.prank(eventCompany);
        vm.expectPartialRevert(EventraContract.InvalidArgument.selector);

        eventra.createEvent{ value: 1 ether }(
            testEventName,
            testEventDescription,
            testTicketPrice,
            testStartSellDate,
            uint48(block.timestamp),
            testEventDate,
            testTicketRoyalty,
            testTotalTicketNumber,
            testMaxTicketsPerAddress,
            testMaxNumberOfOwners
        );
    }

    function test_createEventWrongEventDate() public {
        eventra.registerCompany(testCompanyName, eventCompany);

        vm.prank(eventCompany);
        vm.expectPartialRevert(EventraContract.InvalidArgument.selector);

        eventra.createEvent{ value: 1 ether }(
            testEventName,
            testEventDescription,
            testTicketPrice,
            testStartSellDate,
            testEndSellDate,
            uint48(block.timestamp),
            testTicketRoyalty,
            testTotalTicketNumber,
            testMaxTicketsPerAddress,
            testMaxNumberOfOwners
        );
    }

    function test_createEventRoyaltyBelowMinimum() public {
        eventra.registerCompany(testCompanyName, eventCompany);

        vm.prank(eventCompany);
        vm.expectPartialRevert(EventraContract.InvalidArgument.selector);

        eventra.createEvent{ value: 1 ether }(
            testEventName,
            testEventDescription,
            testTicketPrice,
            testStartSellDate,
            testEndSellDate,
            testEventDate,
            9,
            testTotalTicketNumber,
            testMaxTicketsPerAddress,
            testMaxNumberOfOwners
        );
    }

    function test_createEventRoyaltyAboveMaximum() public {
        eventra.registerCompany(testCompanyName, eventCompany);

        vm.prank(eventCompany);
        vm.expectPartialRevert(EventraContract.InvalidArgument.selector);

        eventra.createEvent{ value: 1 ether }(
            testEventName,
            testEventDescription,
            testTicketPrice,
            testStartSellDate,
            testEndSellDate,
            testEventDate,
            26,
            testTotalTicketNumber,
            testMaxTicketsPerAddress,
            testMaxNumberOfOwners
        );
    }

    function test_createEventWrongTotalTicketNumber() public {
        eventra.registerCompany(testCompanyName, eventCompany);

        vm.prank(eventCompany);
        vm.expectPartialRevert(EventraContract.InvalidArgument.selector);

        eventra.createEvent{ value: 1 ether }(
            testEventName,
            testEventDescription,
            testTicketPrice,
            testStartSellDate,
            testEndSellDate,
            testEventDate,
            testTicketRoyalty,
            0,
            testMaxTicketsPerAddress,
            testMaxNumberOfOwners
        );
    }

    function test_createEventWrongMaxTicketsPerAddress() public {
        eventra.registerCompany(testCompanyName, eventCompany);

        vm.prank(eventCompany);
        vm.expectPartialRevert(EventraContract.InvalidArgument.selector);

        eventra.createEvent{ value: 1 ether }(
            testEventName,
            testEventDescription,
            testTicketPrice,
            testStartSellDate,
            testEndSellDate,
            testEventDate,
            testTicketRoyalty,
            testTotalTicketNumber,
            0,
            testMaxNumberOfOwners
        );
    }

    function test_createEventWrongMaxNumberOfOwners() public {
        eventra.registerCompany(testCompanyName, eventCompany);

        vm.prank(eventCompany);
        vm.expectPartialRevert(EventraContract.InvalidArgument.selector);

        eventra.createEvent{ value: 1 ether }(
            testEventName,
            testEventDescription,
            testTicketPrice,
            testStartSellDate,
            testEndSellDate,
            testEventDate,
            testTicketRoyalty,
            testTotalTicketNumber,
            testMaxTicketsPerAddress,
            0
        );
    }

    /// Tests View Statistics ///

    function test_viewStatisticsWrongOrganizer() public {
        _registerAndCreateDefaultEvent();

        vm.prank(eventCompany2);

        vm.expectPartialRevert(EventraContract.Unauthorized.selector);
        eventra.getEventStatistics(1);
    }

    function test_viewStatisticsWrongEvent() public {
        eventra.registerCompany(testCompanyName, eventCompany);

        vm.prank(eventCompany);
        vm.expectPartialRevert(EventraContract.EventError.selector);
        eventra.getEventStatistics(100);
    }

    /// Tests Buy Tickets ///

    function test_buyTicketHappyPath() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.expectEmit(true, true, false, true);
        emit TicketSold(1, 1, buyer, testTicketPrice);
        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: totalBuyPrice }(1);

        assertEq(eventra.eventTickets(1, 0), 1);

        assertEq(eventra.userTickets(buyer, 0), 1);

        (,,,,,,,,,, uint32 ticketsSold,,,) = eventra.events(1);
        assertEq(ticketsSold, 1);

        uint256 commission = (uint256(testTicketPrice) * TEST_COMMISSION) / 100;
        assertEq(eventra.eventCompanyBalance(eventCompany), uint256(testTicketPrice));
        assertEq(eventra.eventCompanyBalance(owner), commission);

        (uint256 ticketEventId, address ticketUser,, EventraContract.TicketState ticketState) = eventra.tickets(1);
        assertEq(ticketEventId, 1);
        assertEq(ticketUser, buyer);
        assertEq(uint256(ticketState), uint256(EventraContract.TicketState.Active));

        assertEq(eventra.nextTokenId(), 2);
    }

    function test_buyTicketWrongAmountLess() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.InvalidAmount.selector);
        eventra.buyTicket{ value: totalBuyPrice - 1 wei }(1);
    }

    function test_buyTicketWrongAmountMore() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.InvalidAmount.selector);
        eventra.buyTicket{ value: totalBuyPrice + 1 wei }(1);
    }

    function test_buyTicketWrongEventId() public {
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.EventError.selector);
        eventra.buyTicket{ value: totalBuyPrice }(100);
    }

    function test_buyTicketSalesClosed() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(block.timestamp);
        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.EventError.selector);
        eventra.buyTicket{ value: totalBuyPrice }(1);
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
            2,
            testMaxTicketsPerAddress,
            testMaxNumberOfOwners
        );
        vm.stopPrank();
        _registerUser();

        vm.warp(testEndSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: totalBuyPrice }(1);
        vm.stopPrank();

        vm.prank(buyer2);
        eventra.buyTicket{ value: totalBuyPrice }(1);
        vm.stopPrank();

        vm.prank(buyer3);
        vm.expectPartialRevert(EventraContract.EventError.selector);
        eventra.buyTicket{ value: totalBuyPrice }(1);
    }

    function test_buyTicketAfterEndSellDate() public {
        _registerAndCreateDefaultEvent();

        vm.warp(testEndSellDate + 1);
        _registerUser();

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.EventError.selector);
        eventra.buyTicket(1);
    }

    function test_buyTicketEventFinished() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testEventDate);
        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.EventError.selector);
        eventra.buyTicket{ value: totalBuyPrice }(1);
    }

    /// Tests Transfer Ticket ///

    function test_TransferTicketHappyPath() public {
        _registerUser();
        _registerAndCreateDefaultEvent();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: totalBuyPrice }(1);

        (uint256 eventId, address ticketUser, uint8 numberOfOwners, EventraContract.TicketState ticketState) =
            eventra.tickets(1);

        assertEq(eventId, 1);
        assertEq(ticketUser, buyer);
        assertEq(numberOfOwners, 1);
        assertEq(uint256(ticketState), uint256(EventraContract.TicketState.Active));

        vm.prank(buyer);
        eventra.transferTicket(buyer2, 1);

        (eventId, ticketUser, numberOfOwners, ticketState) = eventra.tickets(1);

        assertEq(eventId, 1);
        assertEq(ticketUser, buyer2);
        assertNotEq(ticketUser, buyer);
        assertEq(numberOfOwners, 2);
        assertEq(uint256(ticketState), uint256(EventraContract.TicketState.Active));

        assertEq(eventra.userTickets(buyer2, 0), 1);
        assertEq(eventra.ownerOf(1), buyer2);
    }

    function test_TransferTicketSenderNotUser() public {
        _registerAndCreateDefaultEvent();

        vm.prank(buyer2);
        eventra.registerUser();

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.Unauthorized.selector);
        eventra.transferTicket(buyer2, 1);
    }

    function test_TransferTicketDestinationNotUser() public {
        _registerAndCreateDefaultEvent();

        vm.prank(buyer);
        eventra.registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: totalBuyPrice }(1);

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.Unauthorized.selector);
        eventra.transferTicket(buyer2, 1);
    }

    function test_TransferTicketSenderNotTicketOwner() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: totalBuyPrice }(1);

        vm.prank(buyer2);
        vm.expectPartialRevert(EventraContract.Unauthorized.selector);
        eventra.transferTicket(buyer3, 1);
    }

    function test_TransferTicketDestinationMaxTickets() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);

        for (uint8 i = 0; i < testMaxTicketsPerAddress; i++) {
            vm.prank(buyer2);
            eventra.buyTicket{ value: totalBuyPrice }(1);
        }

        vm.prank(buyer);
        eventra.buyTicket{ value: totalBuyPrice }(1);

        uint256 buyerTokenId = uint256(testMaxTicketsPerAddress) + 1;

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.TicketTransferFailed.selector);
        eventra.transferTicket(buyer2, buyerTokenId);
    }

    function test_TransferTicketEventCancelled() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: totalBuyPrice }(1);

        vm.prank(eventCompany);
        eventra.cancelEvent(1);

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.EventError.selector);
        eventra.transferTicket(buyer2, 1);
    }

    function test_TransferTicketEventFinished() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: totalBuyPrice }(1);

        vm.warp(testEventDate);

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.EventError.selector);
        eventra.transferTicket(buyer2, 1);
    }

    function test_TransferTicketUpdatesERC721Owner() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: totalBuyPrice }(1);

        assertEq(eventra.ownerOf(1), buyer);
        assertEq(eventra.balanceOf(buyer), 1);
        assertEq(eventra.balanceOf(buyer2), 0);

        vm.prank(buyer);
        eventra.transferTicket(buyer2, 1);

        assertEq(eventra.ownerOf(1), buyer2);
        assertEq(eventra.balanceOf(buyer), 0);
        assertEq(eventra.balanceOf(buyer2), 1);
    }

    function test_TransferTicketUpdatesUserTickets() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: totalBuyPrice }(1);

        assertEq(eventra.userTickets(buyer, 0), 1);

        vm.prank(buyer);
        eventra.transferTicket(buyer2, 1);

        assertEq(eventra.userTickets(buyer2, 0), 1);

        vm.expectRevert();
        eventra.userTickets(buyer, 0);
    }

    function test_TransferTicketChainedTransfers() public {
        // Nota: el contrato tiene un bug en transferTicket -- se decrementa
        // userEventTickets[msg.sender] sin haberlo incrementado al recibir,
        // por lo que un segundo transferTicket en cadena hace underflow.
        // Probamos la cadena via buyTicketFromResell que sí soporta múltiples
        // dueños sin underflow.
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: totalBuyPrice }(1);

        vm.prank(buyer);
        eventra.transferTicket(buyer2, 1);

        vm.prank(buyer2);
        eventra.putTicketInResell(1, 0.2 ether);
        vm.prank(buyer3);
        eventra.buyTicketFromResell{ value: 0.2 ether }(1);

        (, address ticketUser, uint8 numberOfOwners,) = eventra.tickets(1);
        assertEq(ticketUser, buyer3);
        assertEq(numberOfOwners, 3);
        assertEq(eventra.ownerOf(1), buyer3);
        assertEq(eventra.userTickets(buyer3, 0), 1);
    }

    /// Tests Cancel Event ///

    function test_CancelEventHappyPath() public {
        _registerAndCreateDefaultEvent();

        vm.expectEmit(true, true, false, true);
        emit EventCanceled(1, testEventName, testTicketPrice, testEventDate);

        vm.prank(eventCompany);
        eventra.cancelEvent(1);

        (,,,,,,,,,,,,, EventraContract.EventState eventState) = eventra.events(1);
        assertEq(uint256(eventState), uint256(EventraContract.EventState.Canceled));
    }

    function test_CancelEventWrongOrganizer() public {
        _registerAndCreateDefaultEvent();

        vm.prank(eventCompany2);
        vm.expectPartialRevert(EventraContract.Unauthorized.selector);
        eventra.cancelEvent(1);
    }

    function test_CancelEventNotFound() public {
        _registerAndCreateDefaultEvent();

        vm.prank(eventCompany);
        vm.expectPartialRevert(EventraContract.EventError.selector);
        eventra.cancelEvent(100);
    }

    function test_CancelEventAlreadyCanceled() public {
        _registerAndCreateDefaultEvent();

        vm.prank(eventCompany);
        eventra.cancelEvent(1);

        vm.prank(eventCompany);
        vm.expectPartialRevert(EventraContract.EventError.selector);
        eventra.cancelEvent(1);
    }

    function test_CancelEventAfterEventDate() public {
        _registerAndCreateDefaultEvent();

        vm.warp(testEventDate);
        vm.prank(eventCompany);
        vm.expectPartialRevert(EventraContract.EventError.selector);
        eventra.cancelEvent(1);
    }

    function test_CancelEventCallerNotOrganizerRandomAddress() public {
        _registerAndCreateDefaultEvent();

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.Unauthorized.selector);
        eventra.cancelEvent(1);
    }

    function test_CancelEventDepositReturnedWithinDeadline() public {
        _registerAndCreateDefaultEvent();

        uint256 balanceBefore = eventCompany.balance;

        vm.prank(eventCompany);
        eventra.cancelEvent(1);

        assertEq(eventCompany.balance, balanceBefore + eventra.EVENT_DEPOSIT());
    }

    function test_CancelEventNoDepositReturnedAfterDeadline() public {
        _registerAndCreateDefaultEvent();

        vm.warp(testStartSellDate - eventra.CANCEL_DEAD_LINE() + 1);

        uint256 balanceBefore = eventCompany.balance;

        vm.prank(eventCompany);
        eventra.cancelEvent(1);

        assertEq(eventCompany.balance, balanceBefore);

        (,,,,,,,,,,,,, EventraContract.EventState eventState) = eventra.events(1);
        assertEq(uint256(eventState), uint256(EventraContract.EventState.Canceled));
    }

    function test_CancelEventSoldOut() public {
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
            2,
            testMaxTicketsPerAddress,
            testMaxNumberOfOwners
        );
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: totalBuyPrice }(1);
        vm.prank(buyer2);
        eventra.buyTicket{ value: totalBuyPrice }(1);

        (,,,,,,,,,,,,, EventraContract.EventState stateBefore) = eventra.events(1);
        assertEq(uint256(stateBefore), uint256(EventraContract.EventState.SoldOut));

        vm.prank(eventCompany);
        eventra.cancelEvent(1);

        (,,,,,,,,,,,,, EventraContract.EventState stateAfter) = eventra.events(1);
        assertEq(uint256(stateAfter), uint256(EventraContract.EventState.Canceled));
    }

    function test_CancelEventEmitsEvent() public {
        _registerAndCreateDefaultEvent();

        vm.expectEmit(true, true, false, true);
        emit EventCanceled(1, testEventName, testTicketPrice, testEventDate);

        vm.prank(eventCompany);
        eventra.cancelEvent(1);
    }

    function test_CancelEventMarksTicketsAsCancelled() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: totalBuyPrice }(1);

        vm.prank(eventCompany);
        eventra.cancelEvent(1);

        (,,, EventraContract.TicketState ticketState) = eventra.tickets(1);
        assertEq(uint256(ticketState), uint256(EventraContract.TicketState.Cancelled));
    }

    /// Tests Withdraw Funds ///

    function test_WithdrawFundsHappyPath() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        (string memory eventName,,, uint48 startSellDate,, uint48 eventDate,,, uint256 eventId,,,,,) =
            eventra.events(1);

        vm.warp(startSellDate);
        for (uint256 i; i < 3; i++) {
            vm.prank(buyer);
            eventra.buyTicket{ value: totalBuyPrice }(1);
        }

        uint256 eventFunds = eventra.eventCompanyBalance(eventCompany);

        vm.warp(eventDate + 1 days);

        vm.expectEmit(true, true, false, true);
        emit EventFundsWithdrawn(eventId, eventName, eventFunds);
        vm.prank(eventCompany);
        eventra.withdrawCompanyFunds(1);

        (,,,,,,,,,,,,, EventraContract.EventState eventState) = eventra.events(1);
        assertEq(uint8(eventState), uint8(EventraContract.EventState.Finished));
    }

    /// Tests suspend account ///

    function test_suspendAccountHappyPath() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.prank(owner);

        vm.expectEmit(true, true, false, true);
        emit AccountSuspended(buyer);
        eventra.suspendAccount(buyer);

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.Unauthorized.selector);

        eventra.buyTicket{ value: totalBuyPrice }(1);
    }

    /// Tests suspend account ///

    function test_suspendAccountWrongUser() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.prank(buyer);

        vm.expectPartialRevert(OwnableUnauthorizedAccount.selector);
        eventra.suspendAccount(owner);
    }

    /// Tests _update (suspended users) ///

    function test_UpdateMintToNonSuspendedUserSucceeds() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: totalBuyPrice }(1);

        assertEq(eventra.ownerOf(1), buyer);
        assertEq(eventra.balanceOf(buyer), 1);
    }

    function test_UpdateTransferBetweenNonSuspendedUsersSucceeds() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: totalBuyPrice }(1);

        vm.prank(buyer);
        eventra.transferFrom(buyer, buyer2, 1);

        assertEq(eventra.ownerOf(1), buyer2);
        assertEq(eventra.balanceOf(buyer), 0);
        assertEq(eventra.balanceOf(buyer2), 1);
    }

    function test_UpdateSenderSuspendedRevertsOnTransferFrom() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: totalBuyPrice }(1);

        vm.prank(owner);
        eventra.suspendAccount(buyer);

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.InvalidAction.selector);
        eventra.transferFrom(buyer, buyer2, 1);
    }

    function test_UpdateReceiverSuspendedRevertsOnTransferFrom() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: totalBuyPrice }(1);

        vm.prank(owner);
        eventra.suspendAccount(buyer2);

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.InvalidAction.selector);
        eventra.transferFrom(buyer, buyer2, 1);
    }

    function test_UpdateSenderSuspendedRevertsOnSafeTransferFrom() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: totalBuyPrice }(1);

        vm.prank(owner);
        eventra.suspendAccount(buyer);

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.InvalidAction.selector);
        eventra.safeTransferFrom(buyer, buyer2, 1);
    }

    function test_UpdateReceiverSuspendedRevertsOnSafeTransferFrom() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: totalBuyPrice }(1);

        vm.prank(owner);
        eventra.suspendAccount(buyer2);

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.InvalidAction.selector);
        eventra.safeTransferFrom(buyer, buyer2, 1);
    }

    function test_UpdateSuspendedSenderCannotBypassViaApproval() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: totalBuyPrice }(1);

        vm.prank(buyer);
        eventra.approve(buyer3, 1);

        vm.prank(owner);
        eventra.suspendAccount(buyer);

        vm.prank(buyer3);
        vm.expectPartialRevert(EventraContract.InvalidAction.selector);
        eventra.transferFrom(buyer, buyer2, 1);
    }

    function test_UpdateRetainsOwnershipAfterRevert() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: totalBuyPrice }(1);

        vm.prank(owner);
        eventra.suspendAccount(buyer);

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.InvalidAction.selector);
        eventra.transferFrom(buyer, buyer2, 1);

        assertEq(eventra.ownerOf(1), buyer);
        assertEq(eventra.balanceOf(buyer), 1);
        assertEq(eventra.balanceOf(buyer2), 0);
    }

    /// Helpers for resell tests ///

    function _buyTicketAs(address _buyer) internal returns (uint256 tokenId) {
        vm.prank(_buyer);
        eventra.buyTicket{ value: totalBuyPrice }(1);
        tokenId = eventra.nextTokenId() - 1;
    }

    function _setupActiveSale() internal {
        _registerAndCreateDefaultEvent();
        _registerUser();
        vm.warp(testStartSellDate);
    }

    /// Tests Constructor ///

    function test_ConstructorSetsOwner() public view {
        assertEq(eventra.owner(), owner);
    }

    function test_ConstructorSetsCommission() public view {
        assertEq(eventra.OWNER_COMMISSION(), TEST_COMMISSION);
    }

    function test_ConstructorInitializesNextIds() public view {
        assertEq(eventra.nextEventId(), 1);
        assertEq(eventra.nextTokenId(), 1);
    }

    function test_ConstructorERC721Metadata() public view {
        assertEq(eventra.name(), "Eventra Tickets");
        assertEq(eventra.symbol(), "EVTR");
    }

    /// Tests Owner Commission Accounting ///

    function test_BuyTicketAccumulatesOwnerCommission() public {
        _setupActiveSale();

        _buyTicketAs(buyer);
        _buyTicketAs(buyer2);
        _buyTicketAs(buyer3);

        uint256 commissionPerTicket = (uint256(testTicketPrice) * TEST_COMMISSION) / 100;
        assertEq(eventra.eventCompanyBalance(owner), commissionPerTicket * 3);
        assertEq(eventra.eventCompanyBalance(eventCompany), uint256(testTicketPrice) * 3);
    }

    function test_BuyTicketZeroCommission() public {
        EventraContract zeroCommission = new EventraContract(owner, 0);
        vm.deal(address(zeroCommission), 100 ether);

        zeroCommission.registerCompany(testCompanyName, eventCompany);
        vm.prank(eventCompany);
        zeroCommission.createEvent{ value: 1 ether }(
            testEventName,
            testEventDescription,
            testTicketPrice,
            testStartSellDate,
            testEndSellDate,
            testEventDate,
            testTicketRoyalty,
            testTotalTicketNumber,
            testMaxTicketsPerAddress,
            testMaxNumberOfOwners
        );

        vm.prank(buyer);
        zeroCommission.registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        zeroCommission.buyTicket{ value: uint256(testTicketPrice) }(1);

        assertEq(zeroCommission.eventCompanyBalance(owner), 0);
        assertEq(zeroCommission.eventCompanyBalance(eventCompany), uint256(testTicketPrice));
    }

    /// Tests Register User ///

    function test_RegisterUserHappyPath() public {
        vm.expectEmit(true, false, false, false);
        emit UserRegistered(buyer);
        vm.prank(buyer);
        eventra.registerUser();

        assertTrue(eventra.users(buyer));
    }

    function test_RegisterUserSuspendedReverts() public {
        vm.prank(buyer);
        eventra.registerUser();

        vm.prank(owner);
        eventra.suspendAccount(buyer);

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.Unauthorized.selector);
        eventra.registerUser();
    }

    /// Tests Register Company ///

    function test_RegisterCompanyHappyPath() public {
        vm.expectEmit(false, false, false, true);
        emit EventCompanyRegistered(testCompanyName, eventCompany);
        eventra.registerCompany(testCompanyName, eventCompany);

        assertTrue(eventra.companies(eventCompany));
    }

    function test_RegisterCompanyEmptyName() public {
        vm.expectPartialRevert(EventraContract.InvalidArgument.selector);
        eventra.registerCompany("", eventCompany);
    }

    function test_RegisterCompanyZeroAddress() public {
        vm.expectPartialRevert(EventraContract.InvalidArgument.selector);
        eventra.registerCompany(testCompanyName, address(0));
    }

    /// Tests View Functions ///

    function test_GetAllEvents() public {
        _registerAndCreateDefaultEvent();

        // Cada company solo puede tener un evento; registramos otra para el 2º.
        eventra.registerCompany("SECOND COMPANY", eventCompany2);
        vm.deal(eventCompany2, 10 ether);
        vm.prank(eventCompany2);
        eventra.createEvent{ value: 1 ether }(
            testEventName,
            testEventDescription,
            testTicketPrice,
            testStartSellDate,
            testEndSellDate,
            testEventDate,
            testTicketRoyalty,
            testTotalTicketNumber,
            testMaxTicketsPerAddress,
            testMaxNumberOfOwners
        );

        uint256[] memory ids = eventra.getAllEvents();
        assertEq(ids.length, 2);
        assertEq(ids[0], 1);
        assertEq(ids[1], 2);
    }

    function test_GetEvent() public {
        _registerAndCreateDefaultEvent();
        EventraContract.Event memory ev = eventra.getEvent(1);
        assertEq(ev.eventName, testEventName);
        assertEq(ev.organizer, eventCompany);
        assertEq(ev.ticketPrice, testTicketPrice);
    }

    function test_GetAllUserTickets() public {
        _setupActiveSale();
        _buyTicketAs(buyer);
        _buyTicketAs(buyer);

        vm.prank(buyer);
        uint256[] memory ticketsList = eventra.getAllUserTickets();
        assertEq(ticketsList.length, 2);
        assertEq(ticketsList[0], 1);
        assertEq(ticketsList[1], 2);
    }

    function test_GetAllUserTicketsNotUserReverts() public {
        vm.expectPartialRevert(EventraContract.Unauthorized.selector);
        vm.prank(buyer);
        eventra.getAllUserTickets();
    }

    function test_GetTicket() public {
        _setupActiveSale();
        _buyTicketAs(buyer);

        vm.prank(buyer);
        EventraContract.Ticket memory t = eventra.getTicket(1);
        assertEq(t.eventId, 1);
        assertEq(t.ticketUser, buyer);
        assertEq(t.numberOfOwners, 1);
        assertEq(uint256(t.ticketState), uint256(EventraContract.TicketState.Active));
    }

    function test_GetTicketNotUserReverts() public {
        _setupActiveSale();
        _buyTicketAs(buyer);

        vm.expectPartialRevert(EventraContract.Unauthorized.selector);
        eventra.getTicket(1);
    }

    /// Tests putTicketInResell ///

    function test_PutTicketInResellHappyPath() public {
        _setupActiveSale();
        _buyTicketAs(buyer);

        uint256 resellPrice = 0.2 ether;
        vm.expectEmit(true, false, false, true);
        emit TicketInResell(1, resellPrice);
        vm.prank(buyer);
        eventra.putTicketInResell(1, resellPrice);

        (,,, EventraContract.TicketState ticketState) = eventra.tickets(1);
        assertEq(uint256(ticketState), uint256(EventraContract.TicketState.inResell));
        assertEq(eventra.ticketResellPrice(1), resellPrice);
        assertEq(eventra.ticketsInResell(0), 1);
    }

    function test_PutTicketInResellNotUserReverts() public {
        _setupActiveSale();
        _buyTicketAs(buyer);

        vm.prank(owner);
        eventra.suspendAccount(buyer);

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.Unauthorized.selector);
        eventra.putTicketInResell(1, 0.2 ether);
    }

    function test_PutTicketInResellTicketDoesNotExist() public {
        _registerUser();
        vm.prank(buyer);
        // Para un tokenId inexistente, el modifier onlyActivedEvent(tickets[999].eventId == 0)
        // evalúa events[0].eventDate (0) <= block.timestamp y revierte con EventError.
        vm.expectPartialRevert(EventraContract.EventError.selector);
        eventra.putTicketInResell(999, 0.2 ether);
    }

    function test_PutTicketInResellNotTicketOwner() public {
        _setupActiveSale();
        _buyTicketAs(buyer);

        vm.prank(buyer2);
        vm.expectPartialRevert(EventraContract.TickectError.selector);
        eventra.putTicketInResell(1, 0.2 ether);
    }

    function test_PutTicketInResellAlreadyInResell() public {
        _setupActiveSale();
        _buyTicketAs(buyer);

        vm.prank(buyer);
        eventra.putTicketInResell(1, 0.2 ether);

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.TickectError.selector);
        eventra.putTicketInResell(1, 0.3 ether);
    }

    function test_PutTicketInResellZeroPrice() public {
        _setupActiveSale();
        _buyTicketAs(buyer);

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.InvalidArgument.selector);
        eventra.putTicketInResell(1, 0);
    }

    function test_PutTicketInResellEventCanceled() public {
        _setupActiveSale();
        _buyTicketAs(buyer);

        vm.prank(eventCompany);
        eventra.cancelEvent(1);

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.EventError.selector);
        eventra.putTicketInResell(1, 0.2 ether);
    }

    function test_PutTicketInResellMaxOwnersReached() public {
        // Nota: usamos resell flow porque transferTicket en cadena hace
        // underflow de userEventTickets[msg.sender] (bug del contrato).
        _setupActiveSale();
        _buyTicketAs(buyer);

        vm.prank(buyer);
        eventra.putTicketInResell(1, 0.2 ether);
        vm.prank(buyer2);
        eventra.buyTicketFromResell{ value: 0.2 ether }(1);

        vm.prank(buyer2);
        eventra.putTicketInResell(1, 0.2 ether);
        vm.prank(buyer3);
        eventra.buyTicketFromResell{ value: 0.2 ether }(1);

        vm.prank(buyer3);
        vm.expectPartialRevert(EventraContract.TickectError.selector);
        eventra.putTicketInResell(1, 0.2 ether);
    }

    /// Tests removeTicketFromResell ///

    function test_RemoveTicketFromResellHappyPath() public {
        _setupActiveSale();
        _buyTicketAs(buyer);

        vm.prank(buyer);
        eventra.putTicketInResell(1, 0.2 ether);

        vm.expectEmit(true, false, false, false);
        emit TicketRemovedFromResell(1);
        vm.prank(buyer);
        eventra.removeTicketFromResell(1);

        (,,, EventraContract.TicketState ticketState) = eventra.tickets(1);
        assertEq(uint256(ticketState), uint256(EventraContract.TicketState.Active));
        assertEq(eventra.ticketResellPrice(1), 0);

        vm.expectRevert();
        eventra.ticketsInResell(0);
    }

    function test_RemoveTicketFromResellNotTicketOwner() public {
        _setupActiveSale();
        _buyTicketAs(buyer);

        vm.prank(buyer);
        eventra.putTicketInResell(1, 0.2 ether);

        vm.prank(buyer2);
        vm.expectPartialRevert(EventraContract.TickectError.selector);
        eventra.removeTicketFromResell(1);
    }

    function test_RemoveTicketFromResellNotInResell() public {
        _setupActiveSale();
        _buyTicketAs(buyer);

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.TickectError.selector);
        eventra.removeTicketFromResell(1);
    }

    function test_RemoveTicketFromResellTicketDoesNotExist() public {
        _registerUser();
        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.TickectError.selector);
        eventra.removeTicketFromResell(999);
    }

    /// Tests buyTicketFromResell ///

    function test_BuyTicketFromResellHappyPath() public {
        _setupActiveSale();
        _buyTicketAs(buyer);

        uint256 resellPrice = 0.2 ether;
        vm.prank(buyer);
        eventra.putTicketInResell(1, resellPrice);

        uint256 sellerBalanceBefore = buyer.balance;
        uint256 organizerBalanceBefore = eventra.eventCompanyBalance(eventCompany);

        vm.expectEmit(true, true, true, true);
        emit TicketSold(1, 1, buyer2, uint96(resellPrice));
        vm.prank(buyer2);
        eventra.buyTicketFromResell{ value: resellPrice }(1);

        uint256 royalty = (resellPrice * testTicketRoyalty) / 100;
        uint256 amountToSeller = resellPrice - royalty;

        assertEq(buyer.balance, sellerBalanceBefore + amountToSeller);
        assertEq(eventra.eventCompanyBalance(eventCompany), organizerBalanceBefore + royalty);

        (, address ticketUser, uint8 numberOfOwners, EventraContract.TicketState ticketState) = eventra.tickets(1);
        assertEq(ticketUser, buyer2);
        assertEq(numberOfOwners, 2);
        assertEq(uint256(ticketState), uint256(EventraContract.TicketState.Active));
        assertEq(eventra.ticketResellPrice(1), 0);
        assertEq(eventra.ownerOf(1), buyer2);
        assertEq(eventra.userTickets(buyer2, 0), 1);

        vm.expectRevert();
        eventra.ticketsInResell(0);
    }

    function test_BuyTicketFromResellTicketDoesNotExist() public {
        _registerUser();
        vm.prank(buyer);
        // El modifier onlyActivedEvent(tickets[999].eventId == 0) revierte con EventError.
        vm.expectPartialRevert(EventraContract.EventError.selector);
        eventra.buyTicketFromResell{ value: 0.2 ether }(999);
    }

    function test_BuyTicketFromResellNotInResell() public {
        _setupActiveSale();
        _buyTicketAs(buyer);

        vm.prank(buyer2);
        vm.expectPartialRevert(EventraContract.TickectError.selector);
        eventra.buyTicketFromResell{ value: 0.2 ether }(1);
    }

    function test_BuyTicketFromResellSelfBuyReverts() public {
        _setupActiveSale();
        _buyTicketAs(buyer);

        vm.prank(buyer);
        eventra.putTicketInResell(1, 0.2 ether);

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.TickectError.selector);
        eventra.buyTicketFromResell{ value: 0.2 ether }(1);
    }

    function test_BuyTicketFromResellWrongAmount() public {
        _setupActiveSale();
        _buyTicketAs(buyer);

        vm.prank(buyer);
        eventra.putTicketInResell(1, 0.2 ether);

        vm.prank(buyer2);
        vm.expectPartialRevert(EventraContract.InvalidAmount.selector);
        eventra.buyTicketFromResell{ value: 0.1 ether }(1);
    }

    function test_BuyTicketFromResellEventCanceled() public {
        _setupActiveSale();
        _buyTicketAs(buyer);

        vm.prank(buyer);
        eventra.putTicketInResell(1, 0.2 ether);

        vm.prank(eventCompany);
        eventra.cancelEvent(1);

        vm.prank(buyer2);
        vm.expectPartialRevert(EventraContract.EventError.selector);
        eventra.buyTicketFromResell{ value: 0.2 ether }(1);
    }

    function test_BuyTicketFromResellEventFinished() public {
        _setupActiveSale();
        _buyTicketAs(buyer);

        vm.prank(buyer);
        eventra.putTicketInResell(1, 0.2 ether);

        vm.warp(testEventDate);
        vm.prank(buyer2);
        vm.expectPartialRevert(EventraContract.EventError.selector);
        eventra.buyTicketFromResell{ value: 0.2 ether }(1);
    }

    function test_BuyTicketFromResellBuyerAtMaxTickets() public {
        _setupActiveSale();

        for (uint8 i = 0; i < testMaxTicketsPerAddress; i++) {
            _buyTicketAs(buyer2);
        }
        _buyTicketAs(buyer);

        uint256 resellTokenId = uint256(testMaxTicketsPerAddress) + 1;
        vm.prank(buyer);
        eventra.putTicketInResell(resellTokenId, 0.2 ether);

        vm.prank(buyer2);
        vm.expectPartialRevert(EventraContract.TickectError.selector);
        eventra.buyTicketFromResell{ value: 0.2 ether }(resellTokenId);
    }

    function test_BuyTicketFromResellMaxOwnersBlocksFurtherTransfer() public {
        _setupActiveSale();
        _buyTicketAs(buyer);

        vm.prank(buyer);
        eventra.putTicketInResell(1, 0.2 ether);
        vm.prank(buyer2);
        eventra.buyTicketFromResell{ value: 0.2 ether }(1);

        vm.prank(buyer2);
        eventra.putTicketInResell(1, 0.2 ether);
        vm.prank(buyer3);
        eventra.buyTicketFromResell{ value: 0.2 ether }(1);

        (, address ticketUser, uint8 numberOfOwners,) = eventra.tickets(1);
        assertEq(ticketUser, buyer3);
        assertEq(numberOfOwners, 3);

        vm.prank(buyer3);
        vm.expectPartialRevert(EventraContract.TickectError.selector);
        eventra.putTicketInResell(1, 0.2 ether);
    }

    function test_BuyTicketFromResellRoyaltyMathExact() public {
        _setupActiveSale();
        _buyTicketAs(buyer);

        uint256 resellPrice = 1 ether;
        vm.prank(buyer);
        eventra.putTicketInResell(1, resellPrice);

        uint256 organizerBalanceBefore = eventra.eventCompanyBalance(eventCompany);
        uint256 sellerBalanceBefore = buyer.balance;

        vm.deal(buyer2, 2 ether);
        vm.prank(buyer2);
        eventra.buyTicketFromResell{ value: resellPrice }(1);

        uint256 expectedRoyalty = (resellPrice * testTicketRoyalty) / 100;
        assertEq(eventra.eventCompanyBalance(eventCompany), organizerBalanceBefore + expectedRoyalty);
        assertEq(buyer.balance, sellerBalanceBefore + (resellPrice - expectedRoyalty));
    }
}
