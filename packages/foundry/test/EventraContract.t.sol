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
            uint256 eventFunds,
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
        assertEq(eventFunds, 0);
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
        vm.expectPartialRevert(EventraContract.EventNotFound.selector);
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
        eventra.buyTicket{ value: testTicketPrice }(1);

        assertEq(eventra.eventTickets(1, 0), 1);

        assertEq(eventra.userTickets(buyer, 0), 1);

        (,,,,,,,,,,, uint32 ticketsSold,,,) = eventra.events(1);
        assertEq(ticketsSold, 1);

        (,,,,,,,,,, uint256 eventFunds,,,,) = eventra.events(1);

        assertEq(eventFunds, 0.1 ether);

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
        eventra.buyTicket{ value: testTicketPrice - 1 wei }(1);
    }

    function test_buyTicketWrongAmountMore() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.InvalidAmount.selector);
        eventra.buyTicket{ value: testTicketPrice + 1 wei }(1);
    }

    function test_buyTicketWrongEventId() public {
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.EventNotFound.selector);
        eventra.buyTicket{ value: testTicketPrice }(100);
    }

    function test_buyTicketSalesClosed() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(block.timestamp);
        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.SalesClosed.selector);
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
            2,
            testMaxTicketsPerAddress,
            testMaxNumberOfOwners
        );
        vm.stopPrank();
        _registerUser();

        vm.warp(testEndSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: testTicketPrice }(1);
        vm.stopPrank();

        vm.prank(buyer2);
        eventra.buyTicket{ value: testTicketPrice }(1);
        vm.stopPrank();

        vm.prank(buyer3);
        vm.expectPartialRevert(EventraContract.EventIsSoldOut.selector);
        eventra.buyTicket{ value: testTicketPrice }(1);
    }

    function test_buyTicketAfterEndSellDate() public {
        _registerAndCreateDefaultEvent();

        vm.warp(testEndSellDate + 1);
        _registerUser();

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.SalesClosed.selector);
        eventra.buyTicket(1);
    }

    function test_buyTicketEventFinished() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testEventDate);
        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.EventFinished.selector);
        eventra.buyTicket{ value: testTicketPrice }(1);
    }

    /// Tests Transfer Ticket ///

    function test_TransferTicketHappyPath() public {
        _registerUser();
        _registerAndCreateDefaultEvent();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: testTicketPrice }(1);

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
        eventra.buyTicket{ value: testTicketPrice }(1);

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.Unauthorized.selector);
        eventra.transferTicket(buyer2, 1);
    }

    function test_TransferTicketSenderNotTicketOwner() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: testTicketPrice }(1);

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
            eventra.buyTicket{ value: testTicketPrice }(1);
        }

        vm.prank(buyer);
        eventra.buyTicket{ value: testTicketPrice }(1);

        uint256 buyerTokenId = uint256(testMaxTicketsPerAddress) + 1;

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.Unauthorized.selector);
        eventra.transferTicket(buyer2, buyerTokenId);
    }

    function test_TransferTicketEventCancelled() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: testTicketPrice }(1);

        vm.prank(eventCompany);
        eventra.cancelEvent(1);

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.InvalidEventState.selector);
        eventra.transferTicket(buyer2, 1);
    }

    function test_TransferTicketEventFinished() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: testTicketPrice }(1);

        vm.warp(testEventDate);
        vm.prank(eventCompany);
        eventra.withdrawFunds(1);

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.InvalidEventState.selector);
        eventra.transferTicket(buyer2, 1);
    }

    function test_TransferTicketUpdatesERC721Owner() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: testTicketPrice }(1);

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
        eventra.buyTicket{ value: testTicketPrice }(1);

        assertEq(eventra.userTickets(buyer, 0), 1);

        vm.prank(buyer);
        eventra.transferTicket(buyer2, 1);

        assertEq(eventra.userTickets(buyer2, 0), 1);

        vm.expectRevert();
        eventra.userTickets(buyer, 0);
    }

    function test_TransferTicketChainedTransfers() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: testTicketPrice }(1);

        vm.prank(buyer);
        eventra.transferTicket(buyer2, 1);

        vm.prank(buyer2);
        eventra.transferTicket(buyer3, 1);

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

        (,,,,,,,,,,,,,, EventraContract.EventState eventState) = eventra.events(1);
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
        vm.expectPartialRevert(EventraContract.EventNotFound.selector);
        eventra.cancelEvent(100);
    }

    function test_CancelEventAlreadyCanceled() public {
        _registerAndCreateDefaultEvent();

        vm.prank(eventCompany);
        eventra.cancelEvent(1);

        vm.prank(eventCompany);
        vm.expectPartialRevert(EventraContract.EventCancelled.selector);
        eventra.cancelEvent(1);
    }

    function test_CancelEventAfterEventDate() public {
        _registerAndCreateDefaultEvent();

        vm.warp(testEventDate);
        vm.prank(eventCompany);
        vm.expectPartialRevert(EventraContract.EventFinished.selector);
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

        (,,,,,,,,,,,,,, EventraContract.EventState eventState) = eventra.events(1);
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
        eventra.buyTicket{ value: testTicketPrice }(1);
        vm.prank(buyer2);
        eventra.buyTicket{ value: testTicketPrice }(1);

        (,,,,,,,,,,,,,, EventraContract.EventState stateBefore) = eventra.events(1);
        assertEq(uint256(stateBefore), uint256(EventraContract.EventState.SoldOut));

        vm.prank(eventCompany);
        eventra.cancelEvent(1);

        (,,,,,,,,,,,,,, EventraContract.EventState stateAfter) = eventra.events(1);
        assertEq(uint256(stateAfter), uint256(EventraContract.EventState.Canceled));
    }

    function test_CancelEventEmitsEvent() public {
        _registerAndCreateDefaultEvent();

        vm.expectEmit(true, true, false, true);
        emit EventCanceled(1, testEventName, testTicketPrice, testEventDate);

        vm.prank(eventCompany);
        eventra.cancelEvent(1);
    }

    function test_CancelEventDoesNotChangeTicketState() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: testTicketPrice }(1);

        vm.prank(eventCompany);
        eventra.cancelEvent(1);

        (,,, EventraContract.TicketState ticketState) = eventra.tickets(1);
        assertEq(uint256(ticketState), uint256(EventraContract.TicketState.Active));
    }

    /// Tests Withdraw Funds ///

    function test_WithdrawFundsHappyPath() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        (string memory eventName,,, uint48 startSellDate,, uint48 eventDate,,, uint256 eventId,,,,,,) =
            eventra.events(1);

        vm.warp(startSellDate);
        for (uint256 i; i < 3; i++) {
            vm.prank(buyer);
            eventra.buyTicket{ value: 0.1 ether }(1);
        }

        (,,,,,,,,,, uint256 eventFunds,,,,) = eventra.events(1);

        vm.warp(eventDate + 1 days);

        vm.expectEmit(true, true, false, true);
        emit EventFundsWithdrawn(eventId, eventName, eventFunds);
        vm.prank(eventCompany);
        eventra.withdrawFunds(1);

        (,,,,,,,,,,,,,, EventraContract.EventState eventState) = eventra.events(1);
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

        eventra.buyTicket{ value: testTicketPrice }(1);
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
        eventra.buyTicket{ value: testTicketPrice }(1);

        assertEq(eventra.ownerOf(1), buyer);
        assertEq(eventra.balanceOf(buyer), 1);
    }

    function test_UpdateTransferBetweenNonSuspendedUsersSucceeds() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: testTicketPrice }(1);

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
        eventra.buyTicket{ value: testTicketPrice }(1);

        vm.prank(owner);
        eventra.suspendAccount(buyer);

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.Unauthorized.selector);
        eventra.transferFrom(buyer, buyer2, 1);
    }

    function test_UpdateReceiverSuspendedRevertsOnTransferFrom() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: testTicketPrice }(1);

        vm.prank(owner);
        eventra.suspendAccount(buyer2);

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.Unauthorized.selector);
        eventra.transferFrom(buyer, buyer2, 1);
    }

    function test_UpdateSenderSuspendedRevertsOnSafeTransferFrom() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: testTicketPrice }(1);

        vm.prank(owner);
        eventra.suspendAccount(buyer);

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.Unauthorized.selector);
        eventra.safeTransferFrom(buyer, buyer2, 1);
    }

    function test_UpdateReceiverSuspendedRevertsOnSafeTransferFrom() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: testTicketPrice }(1);

        vm.prank(owner);
        eventra.suspendAccount(buyer2);

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.Unauthorized.selector);
        eventra.safeTransferFrom(buyer, buyer2, 1);
    }

    function test_UpdateSuspendedSenderCannotBypassViaApproval() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: testTicketPrice }(1);

        vm.prank(buyer);
        eventra.approve(buyer3, 1);

        vm.prank(owner);
        eventra.suspendAccount(buyer);

        vm.prank(buyer3);
        vm.expectPartialRevert(EventraContract.Unauthorized.selector);
        eventra.transferFrom(buyer, buyer2, 1);
    }

    function test_UpdateRetainsOwnershipAfterRevert() public {
        _registerAndCreateDefaultEvent();
        _registerUser();

        vm.warp(testStartSellDate);
        vm.prank(buyer);
        eventra.buyTicket{ value: testTicketPrice }(1);

        vm.prank(owner);
        eventra.suspendAccount(buyer);

        vm.prank(buyer);
        vm.expectPartialRevert(EventraContract.Unauthorized.selector);
        eventra.transferFrom(buyer, buyer2, 1);

        assertEq(eventra.ownerOf(1), buyer);
        assertEq(eventra.balanceOf(buyer), 1);
        assertEq(eventra.balanceOf(buyer2), 0);
    }
}
