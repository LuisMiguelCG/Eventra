// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol"; /*TODO: Echarle un ojo a las extensiones por si necesitamos alguna  https://docs.openzeppelin.com/contracts/5.x/api/token/erc721*/
import "@openzeppelin/contracts/token/ERC721/IERC721.sol"; /*TODO: No se cual es la que debemos usar exactamente */
import "@openzeppelin/contracts/access/Ownable.sol"; /*TODO: Ya existe la libreria asique no nos compliquemos  https://docs.openzeppelin.com/contracts/5.x/api/access#Ownable*/

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
        string eventName;
        string eventDescription;
        uint96 ticketPrice;
        uint48 startSellDate;
        uint48 endSellDate;
        uint48 eventDate;
        uint16 ticketRoyalty;
        uint32 totalTicketNumber;
        uint256 eventId;
        address organizer;
        EventState eventState;
    }

    struct Ticket {
        uint256 eventId;
        uint256 ticketQR;
        address ticketUser;
        uint32 ticketEvent;
        TicketState ticketState;
    }

    struct Company {
        string companyName;
        string phoneNumber;
        address addr;
    }

    /////////////////
    /// Errors //////
    /////////////////

    error InvalidArgument(string argument);
    error InvalidAmount();
    error TicketNotFound();
    error EventNotFound();
    error InvalidEventState();
    error InvalidTicketState();
    error SalesClosed();
    error Unauthorized(string argument);
    error PayoutNotActiveYet();
    error PayoutAlreadyPaid();
    error InvalidAddress();
    error NotValidPayout();
    error TransferFailed();

    //////////////////////
    /// State Variables //
    //////////////////////
    // struct User {}
    

    uint256 public nextEventId;

    uint256 public constant EVENT_DEPOSIT = 1 ether;
    uint16 public constant MINIMUM_ROYALTY = 10;
    uint16 public constant MAXIMUM_ROYALTY = 25;

    mapping(uint256 => Event) events;
    mapping(uint256 => Ticket) tickets;
    mapping(address => mapping(uint256 => uint256)) ticketToEvent;
    mapping(address => uint256[]) userTickets;
    mapping(address => Company) companies;
    mapping(address => uint256[]) companyEvents;

    ////////////////
    /// Events /////
    ////////////////

    event EventCreated(
        uint256 eventId,
        bytes32 eventName,
        uint96 ticketPrice,
        uint48 eventDate
    );

    ///////////////////
    /// Constructor ///
    ///////////////////

    constructor(address _owner) payable Ownable(_owner) {
        nextEventId = 1;
    }
    ///////////////////
    /// Functions /////
    ///////////////////

    function registerUser() external {}
    function loggingUser() external {}
    function searchEvent() external {}
    function buyTicket() external {}
    function viewOurTickets() external {}
    function resendTicket() external {}
    function transferTicket() external {}

    function registerCompany(
        string memory _companyName,
        string memory _phoneNumber,
        address _addr
    ) external {

        if(bytes(_companyName).length == 0)           revert InvalidArgument("Invalid Company Name");
        if(_phoneNumber == 0)                         revert InvalidArgument("Invalid Phone Number");
        if(_addr == address(0))                       revert InvalidArgument("Invalid Company Address");

        companies[_addr] = Company({
            companyName: _companyName,
            phoneNumber: _phoneNumber,
            addr: _addr
        });
    }


    //las fechas se pasarian en formato UNIX: 1778966678 10 digits
    function createEvent(
        string memory _eventName,
        string memory _eventDescription,
        uint96 _ticketPrice,
        uint48 _startSellDate,
        uint48 _endSellDate,
        uint48 _eventDate,
        uint16 _ticketRoyalty,
        uint32 _totalTicketNumber
    ) external payable {

        if(msg.sender != companies[msg.sender].addr)    revert Unauthorized("Not Company");
        if(bytes(_eventName).length == 0)               revert InvalidArgument("Invalid Event Name");
        if(_ticketPrice == 0)                           revert InvalidArgument("Invalid Ticket Price");
        if(_startSellDate <= block.timestamp)           revert InvalidArgument("Invalid Start Time");
        if(_endSellDate <= block.timestamp)             revert InvalidArgument("Invalid End Time");
        if(_eventDate <= block.timestamp)               revert InvalidArgument("Invalid Date Event");
        if(_startSellDate >= _endSellDate)              revert InvalidArgument("Invalid Sell Time");
        if(_ticketRoyalty < MINIMUM_ROYALTY ||  
           _ticketRoyalty > MAXIMUM_ROYALTY)            revert InvalidArgument("Invalid Ticket Royalty");
        if(_totalTicketNumber == 0)                     revert InvalidArgument("Invalid Total Ticket Number");

        uint256 eventId = nextEventId;

        events[eventId] = Event({
            eventName: _eventName,
            eventDescription: _eventDescription,
            ticketPrice: _ticketPrice,
            startSellDate: _startSellDate,
            endSellDate: _endSellDate,
            eventDate: _eventDate,
            ticketRoyalty: _ticketRoyalty,
            totalTicketNumber: _totalTicketNumber,
            eventId: eventId,
            organizer: msg.sender,
            eventState: Active
        });

        nextEventId++;

        emit EventCreated(eventId, _eventName, _ticketPrice, _eventDate);
    }
    function viewStatistics() external {}
    function cancelEvent() external {}
    function withdrawFunds() external {}

    function suspendAccount() external onlyOwner {}

    receive() external payable {}
}
