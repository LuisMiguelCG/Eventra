// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol"; /*TODO: Echarle un ojo a las extensiones por si necesitamos alguna  https://docs.openzeppelin.com/contracts/5.x/api/token/erc721*/

// import "@openzeppelin/contracts/token/ERC721/IERC721.sol"; /*TODO: No se cual es la que debemos usar exactamente */
import "@openzeppelin/contracts/access/Ownable.sol"; /*TODO: Ya existe la libreria asique no nos compliquemos  https://docs.openzeppelin.com/contracts/5.x/api/access#Ownable*/
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; /*Propuesta por chatgpt para cuando hay retirada de fondos*/
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
        EventState eventState;
    }

    struct Ticket {
        uint256 eventId;
        // uint256 ticketQR; // QUESTION: How is this stored?
        address ticketUser; // owner of the ticket. Initially the Company.
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

    //////////////////////
    /// State Variables //
    //////////////////////

    uint256 public constant EVENT_DEPOSIT = 1 ether;
    uint16 public constant MINIMUM_ROYALTY = 10;
    uint16 public constant MAXIMUM_ROYALTY = 25;

    uint256 public nextEventId;
    // Variable para controlar el id del NFT. Se usa para crear
    uint256 public nextTokenId;

    mapping(uint256 => Event) public events; // EventId => Event struct
    mapping(uint256 => string) public eventBaseURI; // EventId => URI base del evento
    // QUESTION: no se cómo de necesario es esto.

    // EventId => numero de tickets vendidos. Se inicializa a 0.
    mapping(uint256 => uint32) public ticketsSold;

    /* EventId => Lista[TokenIds] que pertenecen al evento EventId.
    Usado para:
    1. Al cancelar un evento, cancelar todos los tickets a la vez.
    2. Mostrar estadísticas a Company
    3. En frontend poder gestionar los tickets de un evento
    */
    mapping(uint256 => uint256[]) public eventTickets;
    // OTRA OPCION: codificar el eventId dentro del propio tokenId

    mapping(address => Company) public companies;
    mapping(address => uint256[]) public companyEvents; // QUESTION: Is it necessary? Event has address atb in the struct ...

    mapping(uint256 => Ticket) public tickets;
    // mapping(address => mapping(uint256 => uint256)) ticketToEvent; // OXXXX[1][1] - redundante con tickets[tokenId].eventId

    // User Address => Lista[TokenIds] vinculados al User Address.
    mapping(address => uint256[]) public userTickets;

    ////////////////
    /// Events /////
    ////////////////

    event EventCompanyRegistered(string companyName, address companyAddress); // TIENE SENTIDO??
    event EventCreated(uint256 indexed eventId, string eventName, uint96 ticketPrice, uint48 indexed eventDate);
    event EventCanceled(uint256 indexed eventId, string eventName, uint96 ticketPrice, uint48 indexed eventDate);
    event EventFundsWithdrawn(uint256 indexed eventId, string eventName); //HABRIA QUE VER COMO SE LE PASA EL DINERO OBTENIDO

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
    function registerUser() external { }
    function loggingUser() external { }
    function searchEvent(uint256 eventId) external { }

    function buyTicket(uint256 _eventId) external payable {
        if (_eventId == 0 || _eventId >= nextEventId) revert EventNotFound(_eventId);

        Event storage ev = events[_eventId];

        if (ev.eventState == EventState.SoldOut) revert InvalidEventState();

        if (block.timestamp > ev.endSellDate) revert SalesClosed();
        if (block.timestamp < ev.startSellDate) revert SalesClosed();

        if (msg.value != ev.ticketPrice) revert InvalidAmount(msg.value, ev.ticketPrice);

        uint256 tokenId = nextTokenId;
        nextTokenId += 1;

        tickets[tokenId] = Ticket({
            eventId: _eventId,
            ticketUser: msg.sender,
            ticketState: TicketState.Active
        });

        // Vincula Ticket(TokenId) a Evento
        eventTickets[_eventId].push(tokenId);
        // Vincula Ticket(TokenId) a Usuario
        userTickets[msg.sender].push(tokenId);
        // Suma 1 a la cantidad de tickets del evento vendido.
        ticketsSold[_eventId] += 1;

        // Si se han vendido todos los tickets => el evento pasa a sold out
        if (ticketsSold[_eventId] == ev.totalTicketNumber) ev.eventState = EventState.SoldOut;

        ev.eventFunds += msg.value;

        _safeMint(msg.sender, tokenId);

        emit TicketSold(_eventId, tokenId, msg.sender, ev.ticketPrice);
    } //IMPLEMENTAR UN eventFunds++ el msg.value

    function viewOurTickets() external { }
    function resendTicket() external { }
    function transferTicket() external { }

    //DEBERIAMOS BORRAR ESTO
    /*
    function registerCompany(string memory _companyName, address _addr) external {
        if (bytes(_companyName).length == 0) revert InvalidArgument("Invalid Company Name");
        if (_addr == address(0)) revert InvalidArgument("Invalid Company Address");

        companies[_addr] = Company({ companyName: _companyName, addr: _addr });

        emit EventCompanyRegistered(_companyName, _addr);
    }
    */

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
        if (msg.value != EVENT_DEPOSIT) revert InvalidAmount(msg.value, EVENT_DEPOSIT);
      // if (msg.sender != companies[msg.sender].addr) revert Unauthorized("Not Company");
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
        if (eventId >= nextEventId) revert EventNotFound(eventId); //TIENE SENTIDO?? SE PUEDE TENER UN ID MAYOR???

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
