// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";  /*TODO: Echarle un ojo a las extensiones por si necesitamos alguna  https://docs.openzeppelin.com/contracts/5.x/api/token/erc721*/
import "@openzeppelin/contracts/token/ERC721/IERC721.sol"; /*TODO: No se cual es la que debemos usar exactamente */
import "@openzeppelin/contracts/access/Ownable.sol";       /*TODO: Ya existe la libreria asique no nos compliquemos  https://docs.openzeppelin.com/contracts/5.x/api/access#Ownable*/

/*PODEMOS USAR TAMBIEN UNA LIB PARA EL CONTROL DE ACCESO QUE DA ROLES, ASI PODEMOS ASEGURAR QUE LAS FUNCIONES UNICAS DE USUARIO, EMPRESA, ADMIN SE USAN UNICAMENTE SI ESAS ADDRS SON ESE ROL
  https://docs.openzeppelin.com/contracts/5.x/access-control
  https://docs.openzeppelin.com/contracts/5.x/api/access#AccessControl
*/


contract EventraContract is Ownable {


    //////////////////////
    ///     States      //
    //////////////////////

    /* Currently this is not available, might be implemented later if given enough time
    enum CompanyVerificationState {
        PendingVerification,
        Verified,
        Denied,
        Banned
    }
    */

    enum EventState {
        Active,
        Expired,
        Canceled,
        Finished
    }

    enum TicketState {
        Active,
        Transfered,
        inResell,
        Used,
        Cancelled,
        Reimbursed
    }

    struct Event {
        bytes32 eventName;
        string eventDescription;
        uint96 ticketPrice;
        uint48 startSellDate;
        uint48 endSellDate;
        uint48 eventDate;
        uint16 ticketRoyalty;
        uint32 totalTicketNumber;
    }

    struct Ticket {
        uint256 eventId;
        uint256 ticketQR;
        address ticketUser;
        uint32 ticketEvent;
        TicketState ticketState;
    }

    /////////////////
    /// Errors //////
    /////////////////

    error InvalidAmount();
    error TicketNotFound();
    error EventNotFound();
    error InvalidEventState();
    error InvalidTicketState();
    error SalesClosed();
    error Unauthorized();
    error PayoutNotActiveYet();
    error PayoutAlreadyPaid();
    error InvalidAddress();
    error NotValidPayout();
    error TransferFailed();


    //////////////////////
    /// State Variables //
    //////////////////////

    struct User {}
    struct Company{}

    uint256 public nextEventId;

    uint256 public constant EVENT_DEPOSIT = 1 ether;
    uint16 public constant MINIMUM_ROYALTY = 10;
    uint16 public constant MAXIMUM_ROYALTY = 25;

    mapping(uint256 => Event) events;
    mapping(uint256 => Ticket) tickets;
    mapping(address => mapping(uint256 => uint256)) ticketToEvent;
    mapping(address => uint256[]) userTickets;


    ////////////////
    /// Events /////
    ////////////////

    event EventCreated(uint256 eventId, bytes32 eventName, uint96 ticketPrice, uint48 eventDate);


    ///////////////////
    /// Constructor ///
    ///////////////////

    constructor(address _owner) Ownable(_owner) payable {

        /*if (_owner == address(0)) {
            revert InvalidAddress();
        } ESTO YA LO HACE OWNABLE(_OWNER)*/

        nextEventId = 1;
    }


    ///////////////////
    /// Functions /////
    ///////////////////

    function registerUser(){}
    function logginUser(){}
    function searchEvent(){}
    function buyTicket(){}
    function viewOurTickets(){}
    function resendTicket(){}
    function transferTicket(){}


    function registerCompany(){}
    //las fechas se pasarian en formato UNIX: 1778966678 10 digits
    function createEvent(
        bytes32 _eventName,
        string memory _eventDescription,
        uint96 _ticketPrice,
        uint48 _startSellDate,
        uint48 _endSellDate,
        uint48 _eventDate,
        uint16 _ticketRoyalty,
        uint32 _totalTicketNumber
    ) external payable {
        uint256 eventId = nextEventId;

        Event storage eventraEvent = events[eventId];

        eventraEvent.eventName = _eventName;
        eventraEvent.eventDescription = _eventDescription;
        eventraEvent.ticketPrice = _ticketPrice;
        eventraEvent.startSellDate = _startSellDate;
        eventraEvent.endSellDate = _endSellDate;
        eventraEvent.eventDate = _eventDate;
        eventraEvent.ticketRoyalty = _ticketRoyalty;
        eventraEvent.totalTicketNumber = _totalTicketNumber;

        nextEventId++;

        emit EventCreated(eventId, _eventName, _ticketPrice, _eventDate);
    }
    function viewStatistics(){}
    function cancelEvent(){}
    function withdrawFounds(){}


    function suspendAccount() onlyOwner {}


    receive() external payable { }
}
