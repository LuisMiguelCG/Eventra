// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol"; /*TODO: Echarle un ojo a las extensiones por si necesitamos alguna  https://docs.openzeppelin.com/contracts/5.x/api/token/erc721*/
import "@openzeppelin/contracts/token/ERC721/IERC721.sol"; /*TODO: No se cual es la que debemos usar exactamente */
import "@openzeppelin/contracts/access/Ownable.sol"; /*TODO: Ya existe la libreria asique no nos compliquemos  https://docs.openzeppelin.com/contracts/5.x/api/access#Ownable*/
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; /*Propuesta por chatgpt para cuando hay retirada de fondos*/
/*PODEMOS USAR TAMBIEN UNA LIB PARA EL CONTROL DE ACCESO QUE DA ROLES, ASI PODEMOS ASEGURAR QUE LAS FUNCIONES UNICAS DE USUARIO, EMPRESA, ADMIN SE USAN UNICAMENTE SI ESAS ADDRS SON ESE ROL
  https://docs.openzeppelin.com/contracts/5.x/access-control
  https://docs.openzeppelin.com/contracts/5.x/api/access#AccessControl
*/

contract EventraContract is Ownable {
    /* Actualmente no está implementado, si hay tiempo se puede considerar

    enum CompanyVerificationState {
        PendingVerification,
        Verified,
        Denied,
        Banned
    }
    */

    //////////////////////
    ///     States      //
    //////////////////////

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
        uint256 eventFunds;
        EventState eventState;
    }

    struct Ticket {
        uint256 eventId;
        uint256 ticketQR;
        address ticketUser;
        TicketState ticketState;
        // HAY QUE CREAR PRIMERO EL TICKET Y LUEGO VER COMO SE RELACIONA CON EL EVENTO Y LOS FONDOS
    }

    struct Company {
        string companyName;
        address addr;
    }

    /////////////////
    /// Errors //////
    /////////////////

    error InvalidArgument(string argument);
    error InvalidAmount();
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

    //////////////////////
    /// State Variables //
    //////////////////////

    uint256 public nextEventId;

    uint256 public constant EVENT_DEPOSIT = 1 ether;
    uint16 public constant MINIMUM_ROYALTY = 10;
    uint16 public constant MAXIMUM_ROYALTY = 25;

    mapping(uint256 => Event) events;
    mapping(uint256 => Ticket) tickets;
    mapping(address => mapping(uint256 => uint256)) ticketToEvent; // OXXXX[1][1]
    mapping(address => uint256[]) userTickets;
    mapping(address => Company) companies;
    mapping(address => uint256[]) companyEvents;

    ////////////////
    /// Events /////
    ////////////////

    event EventCompanyRegistered(string companyName, address companyAddress);  // TIENE SENTIDO??
    event EventCreated(uint256 eventId, string eventName, uint96 ticketPrice, uint48 eventDate);
    event EventCanceled(uint256 eventId, string eventName, uint96 ticketPrice, uint48 eventDate);
    event EventFundsWithdrawn(uint256 eventId, string eventName); //HABRIA QUE VER COMO SE LE PASA EL DINERO OBTENIDO

    /////////////////
    /// Modifiers ///
    /////////////////

    modifier eventExists(uint256 _eventId) {
        if (events[_eventId].organizer == address(0)) {
            revert EventNotFound(_eventId);
        }
        _;
    }

    modifier onlyEventOrganizer(uint256 _eventId) {
        if (events[_eventId].organizer != msg.sender) {
            revert Unauthorized("Not Event Organizer");
        }
        _;
    }


    ///////////////////
    /// Constructor ///
    ///////////////////

    constructor(address _owner) payable Ownable(_owner) {
        nextEventId = 1;
    }

    ///////////////////
    /// Functions /////
    ///////////////////

    receive() external payable { }
    function registerUser() external { }
    function loggingUser() external { }
    function searchEvent(uint256 eventId) external { }
    function buyTicket() external { } //IMPLEMENTAR UN eventFunds++ el msg.value
    function viewOurTickets() external { }
    function resendTicket() external { }
    function transferTicket() external { }

    function registerCompany(string memory _companyName, address _addr) external {
        if (bytes(_companyName).length == 0) revert InvalidArgument("Invalid Company Name");
        if (_addr == address(0)) revert InvalidArgument("Invalid Company Address");

        companies[_addr] = Company({ companyName: _companyName, addr: _addr });

        emit EventCompanyRegistered(_companyName, _addr);
    }

    //las fechas se pasarian en formato UNIX: 1234567890 10 digits
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
        if (msg.value != EVENT_DEPOSIT) revert InvalidAmount();
        if (msg.sender != companies[msg.sender].addr) revert Unauthorized("Not Company");
        if (bytes(_eventName).length == 0) revert InvalidArgument("Invalid Event Name");
        if (_ticketPrice == 0) revert InvalidArgument("Invalid Ticket Price");
        if (_startSellDate <= block.timestamp) revert InvalidArgument("Invalid Start Time");
        if (_endSellDate <= block.timestamp) revert InvalidArgument("Invalid End Time");
        if (_eventDate <= block.timestamp) revert InvalidArgument("Invalid Date Event");
        if (_startSellDate >= _endSellDate) revert InvalidArgument("Invalid Sell Time");
        if (_ticketRoyalty < MINIMUM_ROYALTY || _ticketRoyalty > MAXIMUM_ROYALTY) {
            revert InvalidArgument("Invalid Ticket Royalty");
        }
        if (_totalTicketNumber == 0) revert InvalidArgument("Invalid Total Ticket Number");

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
            eventState: EventState.Active,
            eventFunds: 0
        });

        nextEventId++;

        emit EventCreated(eventId, _eventName, _ticketPrice, _eventDate);
    }

    function viewStatistics(uint256 eventId) 
        external
        view
        eventExists(eventId)
        onlyEventOrganizer(eventId)
        returns (
            string memory _eventName,
            string memory _eventDescription,
            uint96 _ticketPrice,
            uint48 _startSellDate,
            uint48 _endSellDate,
            uint48 _eventDate,
            uint16 _ticketRoyalty,
            uint32 _totalTicketNumber
        )
    {
        Event storage eventra = events[eventId];  

        return (
            eventra.eventName,
            eventra.eventDescription,
            eventra.ticketPrice,
            eventra.startSellDate,
            eventra.endSellDate,
            eventra.eventDate,
            eventra.ticketRoyalty,
            eventra.totalTicketNumber
        );
    }

    function cancelEvent(uint256 eventId) external eventExists(eventId) onlyEventOrganizer(eventId) {
        if (eventId >= nextEventId) revert EventNotFound(eventId);  //TIENE SENTIDO?? SE PUEDE TENER UN ID MAYOR???

        Event storage eventra = events[eventId];                                    // SOLO FINALIZAMOS EVENTO AL RETIRAR FONDOS, PERO Y SI EL EVENTO HA TERMINADO Y SE
        if (eventra.eventState != EventState.Active) revert InvalidEventState();    // LE DA CANCELAR??
        if (block.timestamp > eventra.eventDate) revert InvalidEventState(); 
        eventra.eventState = EventState.Canceled;                                 

        // if (block.timestamp <= events[eventId].startSellDate - 1 days) SE DEVUELVE LA PASTA
        bool isSellPeriod = eventra.startSellDate <= block.timestamp && eventra.endSellDate >= block.timestamp;  //SE PUEDE AÑADIR UNA POLITICA DE QUE PARA RECUPERAR LA PASTA
        if (!isSellPeriod) {                                                                                     // HAYA QUE CANCELAR 1 DIA (O LO QUE SEA) ANTES DEL SELL PERIOD   
            (bool ok,) = msg.sender.call{ value: EVENT_DEPOSIT }("");
            if (!ok) revert TransferFailed(msg.sender, EVENT_DEPOSIT);
        }

        emit EventCanceled(eventId, eventra.eventName, eventra.ticketPrice, eventra.eventDate);
    }

    function withdrawFunds(uint256 eventId) external eventExists(eventId) onlyEventOrganizer(eventId) {

        Event storage eventra = events[eventId];
        if (eventra.eventState != EventState.Finished) revert InvalidEventState();      // ESTO NO ESTA BIEN, SOLO SE FINALIZA EL EVENTO AQUI, ASIQUE SIEMPRE VA A REVERTIR

        eventra.eventState = EventState.Finished;

        (bool ok,) = msg.sender.call{ value: eventra.eventFunds }(""); //DEFINIR QUE SE PAGA
        if (!ok) revert TransferFailed(msg.sender, eventra.eventFunds);

        emit EventFundsWithdrawn(eventId, eventra.eventName);
    }

    function suspendAccount() external onlyOwner { }

}
