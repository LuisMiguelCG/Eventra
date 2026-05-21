// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol"; /*TODO: Echarle un ojo a las extensiones por si necesitamos alguna  https://docs.openzeppelin.com/contracts/5.x/api/token/erc721*/

// import "@openzeppelin/contracts/token/ERC721/IERC721.sol"; /*TODO: No se cual es la que debemos usar exactamente */
import "@openzeppelin/contracts/access/Ownable.sol"; /*TODO: Ya existe la libreria asique no nos compliquemos  https://docs.openzeppelin.com/contracts/5.x/api/access#Ownable*/
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; /*Propuesta por chatgpt para cuando hay retirada de fondos*/
/*PODEMOS USAR TAMBIEN UNA LIB PARA EL CONTROL DE ACCESO QUE DA ROLES, ASI PODEMOS ASEGURAR QUE LAS FUNCIONES UNICAS DE USUARIO, EMPRESA, ADMIN SE USAN UNICAMENTE SI ESAS ADDRS SON ESE ROL
  https://docs.openzeppelin.com/contracts/5.x/access-control
  https://docs.openzeppelin.com/contracts/5.x/api/access#AccessControl
*/

contract EventraContract is ERC721, Ownable {
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

    /*
    Possible states an event can have:
        - Active: Tickets can still be bought, sold, and used.
        - Expired: ? -- There is nothing in the blueprint about "Expired"
        - SoldOut: There are no more tickets available for the company to sell.
        - Canceled: The company canceled the event. Tickets can only be reimbursed.
        - Finished: The event is finished. Tickets cannot be used in any way
    */
    enum EventState {
        Active,
        Expired,
        SoldOut,
        Canceled,
        Finished
    }

    /*
    Possible states a ticket can have:
        - Active: Ticket can still be bought, sold, and used.
        - Transfered: Ticket is no longer of User's property, so there is nothing you can do with it.
        - inResell: Ticket is in the resell marketplace. It cannot be used or transferred.
        - Used: The Ticket has already been used, so you can't transfer it, use it again, or resell it.
        - Cancelled: Ticket has been canceled by the Company. You can only reimburse it.
        - Reimbursed: It has already been reimbursed, so you cannot do anything with it.
    */
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
        uint16 ticketRoyalty; // Percentage of the resell a company gets when a ticket is resold.
        uint32 totalTicketNumber; // Number of ticket NFTs to be minted.
        uint256 eventId;
        address organizer; // EventCompany address
        uint256 eventFunds;
        uint32 ticketsSold; // Number of tickets sold. Initially 0.
        uint8 maxTicketsPerAddress;
        uint8 maxNumberOfOwners;
        EventState eventState;
    }

    struct Ticket {
        uint256 eventId;
        // uint256 ticketQR; // QUESTION: How is this stored?
        address ticketUser; // owner of the ticket. Initially the Company.
        uint8 numberOfOwners;
        TicketState ticketState;
        // HAY QUE CREAR PRIMERO EL TICKET Y LUEGO VER COMO SE RELACIONA CON EL EVENTO Y LOS FONDOS
    }

    /////////////////
    /// Errors //////
    /////////////////

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

    //////////////////////
    /// State Variables //
    //////////////////////

    uint256 public constant EVENT_DEPOSIT = 1 ether;
    uint16 public constant MINIMUM_ROYALTY = 10;
    uint16 public constant MAXIMUM_ROYALTY = 25;
    uint256 public constant CANCEL_DEAD_LINE = 1 days;

    uint256 public nextEventId;
    // Variable para controlar el id del NFT. Se usa para crear
    uint256 public nextTokenId;

    mapping(uint256 => Event) public events; // EventId => Event struct
    mapping(uint256 => string) public eventBaseURI; // EventId => URI base del evento
    // QUESTION: no se cómo de necesario es esto.

    /* EventId => Lista[TokenIds] que pertenecen al evento EventId.
    Usado para:
    1. Al cancelar un evento, cancelar todos los tickets a la vez.
    2. Mostrar estadísticas a Company
    3. En frontend poder gestionar los tickets de un evento
    */
    mapping(uint256 => uint256[]) public eventTickets;
    // OTRA OPCION: codificar el eventId dentro del propio tokenId

    mapping(address => bool) public users;
    mapping(address => bool) public companies;
    mapping(address => mapping(uint256 => Event)) public companyEvents; // QUESTION: Is it necessary? Addr => EventId => Event struct

    mapping(uint256 => Ticket) public tickets;
    // mapping(address => mapping(uint256 => uint256)) ticketToEvent; // OXXXX[1][1] - redundante con tickets[tokenId].eventId

    // User Address => Lista[TokenIds] vinculados al User Address.
    mapping(address => uint256[]) public userTickets;

    //  mapping(uint256 => Ticket) tickets; // QUESTION: why this var and ticketToEvent?
    // mapping(address => mapping(uint256 => uint256)) ticketToEvent; // OXXXX[1][1]

    // User Address => Lista[TokenIds] vinculados al User Address.
    //  mapping(address => uint256[]) userTickets;

    ////////////////
    /// Events /////
    ////////////////

    event UserRegistered(address indexed user);
    event EventCompanyRegistered(string companyName, address companyAddress); // TIENE SENTIDO??
    event EventCreated(uint256 indexed eventId, string indexed eventName, uint96 ticketPrice, uint48 indexed eventDate);
    event EventCanceled(
        uint256 indexed eventId, string indexed eventName, uint96 ticketPrice, uint48 indexed eventDate
    );
    event EventFundsWithdrawn(uint256 indexed eventId, string indexed eventName, uint256 amount); //HABRIA QUE VER COMO SE LE PASA EL DINERO OBTENIDO
    event EventSoldOut(uint256 indexed eventId, string indexed eventName);
    event TicketSold(uint256 indexed eventId, uint256 indexed tokenId, address indexed buyer, uint96 price);

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

    modifier onlyCompany(address _companyAddr) {
        if (!companies[_companyAddr]) {
            revert Unauthorized("Not Company");
        }
        _;
    }

    modifier onlyActivedEvent(uint256 _eventId) {
        if (block.timestamp >= events[_eventId].eventDate) {
            revert EventFinished(_eventId);
        }

        if (events[_eventId].eventState == EventState.Canceled) {
            revert EventCancelled(_eventId);
        }
        _;
    }

    ///////////////////
    /// Constructor ///
    ///////////////////

    constructor(address _owner) payable ERC721("Eventra Tickets", "EVTR") Ownable(_owner) {
        nextEventId = 1;
        nextTokenId = 1;
    }

    ///////////////////
    /// Functions /////
    ///////////////////

    receive() external payable { }

    function registerUser() external {
        users[msg.sender] = true;
        emit UserRegistered(msg.sender);
    }

    function loggingUser() external { }

    function searchEvent(uint256 eventId)
        external
        view
        eventExists(eventId)
        returns (
            string memory _eventName,
            string memory _eventDescription,
            uint96 _ticketPrice,
            uint48 _startSellDate,
            uint48 _endSellDate,
            uint48 _eventDate,
            uint32 _ticketsLeft,
            uint8 _maxTicketsPerAddress
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
            eventra.totalTicketNumber - eventra.ticketsSold,
            eventra.maxTicketsPerAddress
        );
    }

    function checkNumberOfTicketsOfUserForOneEvent(uint256 _eventId, address _user) private view returns (uint8 _numberOfTickets) {
        uint256[] memory temp = userTickets[_user];
        uint8 ticketsOfUserForEvent = 0;
        for (uint256 i = 0; i < temp.length; i++) {
            uint256 ticket = temp[i];
            if (tickets[ticket].eventId == _eventId) {
                ticketsOfUserForEvent += 1;
            }
        }
        return ticketsOfUserForEvent;
    }

    function buyTicket(uint256 _eventId) external payable eventExists(_eventId) onlyActivedEvent(_eventId) {
        Event storage eventra = events[_eventId];
        if (eventra.eventState == EventState.SoldOut) revert EventIsSoldOut(_eventId);
        if (block.timestamp > eventra.endSellDate || block.timestamp < eventra.startSellDate) {
            revert SalesClosed(_eventId);
        }
        if (msg.value != eventra.ticketPrice) revert InvalidAmount(msg.value, eventra.ticketPrice);

        if (checkNumberOfTicketsOfUserForOneEvent(_eventId, msg.sender) == eventra.maxTicketsPerAddress) {
            revert Unauthorized("You reached the max number of tickets you can buy for this event.");
        }

        uint256 tokenId = nextTokenId;
        nextTokenId++;

        tickets[tokenId] = Ticket({ eventId: _eventId, ticketUser: msg.sender, numberOfOwners: 1, ticketState: TicketState.Active });

        // Vincula Ticket(TokenId) a Evento
        eventTickets[_eventId].push(tokenId);
        // Vincula Ticket(TokenId) a Usuario
        userTickets[msg.sender].push(tokenId);
        // Suma 1 a la cantidad de tickets del evento vendido.
        eventra.ticketsSold += 1;

        // Si se han vendido todos los tickets => el evento pasa a sold out
        if (eventra.ticketsSold == eventra.totalTicketNumber) {
            eventra.eventState = EventState.SoldOut;
            emit EventSoldOut(_eventId, eventra.eventName); // HAY QUE VER SI ES NECESARIO ESTE EVENTO O NO
        }
        eventra.eventFunds += msg.value;

        _safeMint(msg.sender, tokenId);

        emit TicketSold(_eventId, tokenId, msg.sender, eventra.ticketPrice);
    }

    function viewOurTickets() external { }
    function resendTicket() external { }
    function transferTicket() external { }

    function registerCompany(string memory _companyName, address _addr) external {
        // SI QUIERES BORRAR ESTO, COMO TE ASEGURAS DE QUE SOLO
        if (bytes(_companyName).length == 0) revert InvalidArgument("Invalid Company Name"); // CREEN EVENTOS LAS EMPRESAS REGISTRADAS?
        if (_addr == address(0)) revert InvalidArgument("Invalid Company Address"); //
        //
        companies[_addr] = true; //
        //
        emit EventCompanyRegistered(_companyName, _addr); //
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
    ) external payable onlyCompany(msg.sender) {
        if (msg.value != EVENT_DEPOSIT) revert InvalidAmount(msg.value, EVENT_DEPOSIT);
        if (bytes(_eventName).length == 0) revert InvalidArgument("Invalid Event Name");
        if (bytes(_eventDescription).length == 0) revert InvalidArgument("Invalid Event Description");
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
            eventFunds: 0,
            ticketsSold: 0
        });

        nextEventId++;

        emit EventCreated(eventId, _eventName, _ticketPrice, _eventDate);
    }

    function viewStatistics(uint256 eventId)
        external
        view
        eventExists(eventId)
        onlyEventOrganizer(eventId)
        returns (uint256 eventBalance, uint32 ticketsSoldNumber, uint32 ticketsLeft)
    {
        Event storage eventra = events[eventId];

        return (eventra.eventFunds, eventra.ticketsSold, eventra.totalTicketNumber - eventra.ticketsSold);
    }

    function cancelEvent(uint256 eventId)
        external
        eventExists(eventId)
        onlyEventOrganizer(eventId)
        onlyActivedEvent(eventId)
    {
        Event storage eventra = events[eventId];
        eventra.eventState = EventState.Canceled;

        if (block.timestamp <= eventra.startSellDate - CANCEL_DEAD_LINE) {
            (bool ok,) = msg.sender.call{ value: EVENT_DEPOSIT }("");
            if (!ok) revert TransferFailed(msg.sender, EVENT_DEPOSIT);
        }

        emit EventCanceled(eventId, eventra.eventName, eventra.ticketPrice, eventra.eventDate);
    }

    function withdrawFunds(uint256 eventId) external eventExists(eventId) onlyEventOrganizer(eventId) {
        Event storage eventra = events[eventId];
        if (block.timestamp < eventra.eventDate) revert EventNotFinished(eventId);

        uint256 amount = eventra.eventFunds;
        if (amount == 0) revert NotFundsToWithdraw(msg.sender, eventId);

        eventra.eventState = EventState.Finished;
        eventra.eventFunds = 0;

        (bool ok,) = msg.sender.call{ value: amount }("");
        if (!ok) revert TransferFailed(msg.sender, amount);

        emit EventFundsWithdrawn(eventId, eventra.eventName, amount);
    }

    function suspendAccount() external onlyOwner { }
}
