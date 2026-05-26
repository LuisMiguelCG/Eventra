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
    }

    /////////////////
    /// Errors //////
    /////////////////

    error InvalidArgument(string argument);
    error InvalidAmount(uint256 sent, uint256 required);
    error TicketNotFound(string argument);
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
    error InvalidAmountOfTicketOwners();
    error TicketTransferFailed();

    //////////////////////
    /// State Variables //
    //////////////////////

    uint256 public constant EVENT_DEPOSIT = 1 ether;
    uint16 public constant MINIMUM_ROYALTY = 10;
    uint16 public constant MAXIMUM_ROYALTY = 25;
    uint256 public constant CANCEL_DEAD_LINE = 1 days;
    
    uint256 public immutable TICKET_BUYING_COMISSION;

    uint256 public nextEventId;
    uint256 public nextTokenId; // Variable para controlar el id del NFT. Se usa para crear
    uint256[] public eventsIds;

    mapping(address => bool) public users;
    mapping(address => bool) public suspendedUsers;
    mapping(address => bool) public companies;
    mapping(address => uint256) public eventCompanyBalance;

    mapping(uint256 => Event) public events; // EventId => Event struct
    mapping(address => uint256[]) public companyEvents; // Addr => Lista de EventId

    mapping(uint256 => uint256[]) public eventTickets; // EventId => Lista de TokenId - OTRA OPCION: codificar el eventId dentro del propio tokenId

    mapping(uint256 => Ticket) public tickets; // TokenId => Ticket struct.
    mapping(address => uint256[]) public userTickets; // User Address => Lista de TokenId vinculados al User Address.

    ////////////////
    /// Events /////
    ////////////////

    event UserRegistered(address indexed user);
    event EventCompanyRegistered(string companyName, address companyAddress); // TIENE SENTIDO??
    event EventCreated(uint256 indexed eventId, string indexed eventName, uint96 ticketPrice, uint48 indexed eventDate);
    event EventCanceled(
        uint256 indexed eventId, string indexed eventName, uint96 ticketPrice, uint48 indexed eventDate
    );
    event EventFundsWithdrawn(uint256 indexed eventId, string indexed eventName, uint256 amount);
    event EventSoldOut(uint256 indexed eventId, string indexed eventName);
    event TicketSold(uint256 indexed eventId, uint256 indexed tokenId, address indexed buyer, uint96 price);
    event AccountSuspended(address indexed userSuspended);

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

    modifier onlyUser(address _userAddr) {
        if (!users[_userAddr]) {
            revert Unauthorized("Not User");
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

    constructor(address _owner, uint256 _ticketBuyingComission) payable ERC721("Eventra Tickets", "EVTR") Ownable(_owner) {
        nextEventId = 1;
        nextTokenId = 1;
        TICKET_BUYING_COMISSION = _ticketBuyingComission;
    }

    ///////////////////
    /// Functions /////
    ///////////////////

    function registerUser() external {
        if (suspendedUsers[msg.sender]) revert Unauthorized("Suspended user");

        users[msg.sender] = true;
        emit UserRegistered(msg.sender);
    }

    function checkNumberOfTicketsOfUserForOneEvent(uint256 _eventId, address _user)
        internal
        view
        returns (uint8 _numberOfTickets)
    {
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
        if (users[msg.sender] == false) {
            revert Unauthorized("You are not an user of Eventra. Please sign in / log in");
        }
        Event storage eventra = events[_eventId];

        if (eventra.eventState == EventState.SoldOut) {
            revert EventIsSoldOut(_eventId);
        }
        if (block.timestamp > eventra.endSellDate || block.timestamp < eventra.startSellDate) {
            revert SalesClosed(_eventId);
        }
        if (msg.value != eventra.ticketPrice) {
            revert InvalidAmount(msg.value, eventra.ticketPrice);
        }

        uint256 amountToOwner = (eventra.ticketPrice * TICKET_BUYING_COMISSION) / 100;

        if (checkNumberOfTicketsOfUserForOneEvent(_eventId, msg.sender) == eventra.maxTicketsPerAddress) {
            revert Unauthorized("You reached the max number of tickets you can buy for this event.");
        }

        uint256 tokenId = nextTokenId;
        nextTokenId++;

        tickets[tokenId] =
            Ticket({ eventId: _eventId, ticketUser: msg.sender, numberOfOwners: 1, ticketState: TicketState.Active });

        eventTickets[_eventId].push(tokenId);
        userTickets[msg.sender].push(tokenId);
        eventra.ticketsSold += 1;

        if (eventra.ticketsSold == eventra.totalTicketNumber) {
            eventra.eventState = EventState.SoldOut;
            emit EventSoldOut(_eventId, eventra.eventName);
        }

        eventCompanyBalance[eventra.organizer] += msg.value - amountToOwner;

        _safeMint(msg.sender, tokenId);

        emit TicketSold(_eventId, tokenId, msg.sender, eventra.ticketPrice);
    }

    function deleteTicketFromUser(address _user, uint256 _ticket) internal returns (bool _ok) {
        uint256[] storage userList = userTickets[_user];
        uint256 len = userList.length;

        for (uint256 i = 0; i < len; i++) {
            if (userList[i] == _ticket) {
                userList[i] = userList[len - 1];
                userList.pop();
                return true;
            }
        }

        return false;
    }

    function transferTicket(address _to, uint256 _ticketId) external {
        if (!users[msg.sender]) {
            revert Unauthorized("You are not an user of Eventra. Please sign in / log in");
        }
        if (!users[_to]) {
            revert Unauthorized("Destination is not an user of Eventra. Please be sure the account is an Eventra's user");
        }

        Ticket storage ticket = tickets[_ticketId];
        if (ticket.ticketUser != msg.sender) revert Unauthorized("Wrong user");

        if (checkNumberOfTicketsOfUserForOneEvent(ticket.eventId, _to) == events[ticket.eventId].maxTicketsPerAddress) {
            revert Unauthorized("Destination reached the max number of tickets it can get for this event.");
        }

        if (ticket.ticketState != TicketState.Active) {
            revert InvalidTicketState();
        }

        Event storage ev = events[ticket.eventId];
        if (ev.eventState != EventState.Active && ev.eventState != EventState.SoldOut) revert InvalidEventState();

        if (ticket.numberOfOwners >= ev.maxNumberOfOwners) {
            revert InvalidAmountOfTicketOwners();
        }
        ticket.numberOfOwners += 1;
        tickets[_ticketId].ticketUser = _to;

        bool ok = deleteTicketFromUser(msg.sender, _ticketId);
        if (!ok) revert TicketTransferFailed();
        userTickets[_to].push(_ticketId);

        _safeTransfer(msg.sender, _to, _ticketId);
    }

    function getAllUserTickets() external view onlyUser(msg.sender) returns (uint256[] memory) {
        return userTickets[msg.sender];
    }

    function getTicket(uint256 _tokenId) external view onlyUser(msg.sender) returns (Ticket memory) {
        return tickets[_tokenId];
    }

    function getAllEvents() external view returns (uint256[] memory) {
        return eventsIds;
    }

    function getEvent(uint256 _eventId) external view returns (Event memory) {
        return events[_eventId];
    }

    function registerCompany(string memory _companyName, address _addr) external {
        if (bytes(_companyName).length == 0) {
            revert InvalidArgument("Invalid Company Name");
        }
        if (_addr == address(0)) {
            revert InvalidArgument("Invalid Company Address");
        }

        companies[_addr] = true;

        emit EventCompanyRegistered(_companyName, _addr);
    }

    function createEvent(
        string memory _eventName,
        string memory _eventDescription,
        uint96 _ticketPrice,
        uint48 _startSellDate, //las fechas se pasarian en formato UNIX: 1234567890 10 digits
        uint48 _endSellDate, //las fechas se pasarian en formato UNIX: 1234567890 10 digits
        uint48 _eventDate, //las fechas se pasarian en formato UNIX: 1234567890 10 digits
        uint16 _ticketRoyalty,
        uint32 _totalTicketNumber,
        uint8 _maxTicketsPerAddress,
        uint8 _maxNumberOfOwners
    ) external payable onlyCompany(msg.sender) {
        if (msg.value != EVENT_DEPOSIT) {
            revert InvalidAmount(msg.value, EVENT_DEPOSIT);
        }
        if (bytes(_eventName).length == 0) {
            revert InvalidArgument("Invalid Event Name");
        }
        if (bytes(_eventDescription).length == 0) {
            revert InvalidArgument("Invalid Event Description");
        }
        if (_ticketPrice == 0) revert InvalidArgument("Invalid Ticket Price");
        if (_startSellDate <= block.timestamp) {
            revert InvalidArgument("Invalid Start Time");
        }
        if (_endSellDate <= block.timestamp) {
            revert InvalidArgument("Invalid End Time");
        }
        if (_eventDate <= block.timestamp) {
            revert InvalidArgument("Invalid Date Event");
        }
        if (_startSellDate >= _endSellDate) {
            revert InvalidArgument("Invalid Sell Time");
        }
        if (_ticketRoyalty < MINIMUM_ROYALTY || _ticketRoyalty > MAXIMUM_ROYALTY) {
            revert InvalidArgument("Invalid Ticket Royalty");
        }
        if (_totalTicketNumber == 0) {
            revert InvalidArgument("Invalid Total Ticket Number");
        }
        if (_maxTicketsPerAddress == 0) {
            revert InvalidArgument("Invalid Max Tickets per Address");
        }
        if (_maxNumberOfOwners == 0) {
            revert InvalidArgument("Invalid Max Number of Owners");
        }

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
            ticketsSold: 0,
            maxNumberOfOwners: _maxNumberOfOwners,
            maxTicketsPerAddress: _maxTicketsPerAddress
        });

        eventsIds.push(eventId);
        nextEventId++;

        emit EventCreated(eventId, _eventName, _ticketPrice, _eventDate);
    }

    function getEventStatistics(uint256 _eventId)
        external
        view
        eventExists(_eventId)
        onlyEventOrganizer(_eventId)
        returns (uint256 eventBalance, uint32 ticketsSold, uint32 ticketsLeft, uint256 sellThroughRate)
    {
        Event storage eventra = events[_eventId];
        ticketsLeft = eventra.totalTicketNumber - eventra.ticketsSold;
        sellThroughRate = (eventra.ticketsSold * 100) / eventra.totalTicketNumber;

        return (eventra.eventFunds, eventra.ticketsSold, ticketsLeft, sellThroughRate);
    }

    function cancelEvent(uint256 _eventId)
        external
        eventExists(_eventId)
        onlyEventOrganizer(_eventId)
        onlyActivedEvent(_eventId)
    {
        Event storage eventra = events[_eventId];
        eventra.eventState = EventState.Canceled;

        if (block.timestamp <= eventra.startSellDate - CANCEL_DEAD_LINE) {
            (bool ok,) = msg.sender.call{ value: EVENT_DEPOSIT }("");
            if (!ok) revert TransferFailed(msg.sender, EVENT_DEPOSIT);
        }

        emit EventCanceled(_eventId, eventra.eventName, eventra.ticketPrice, eventra.eventDate);
    }

    function withdrawFunds(uint256 _eventId) external eventExists(_eventId) onlyEventOrganizer(_eventId) {
        Event storage eventra = events[_eventId];
        if (block.timestamp < eventra.eventDate) {
            revert EventNotFinished(_eventId);
        }

        uint256 amount = eventra.eventFunds;
        if (amount == 0) revert NotFundsToWithdraw(msg.sender, _eventId);

        eventra.eventState = EventState.Finished;
        eventra.eventFunds = 0;

        (bool ok,) = msg.sender.call{ value: amount }("");
        if (!ok) revert TransferFailed(msg.sender, amount);

        emit EventFundsWithdrawn(_eventId, eventra.eventName, amount);
    }

    function suspendAccount(address userToSuspend) external onlyOwner {
        if (userToSuspend == address(0)) {
            revert InvalidArgument("User not found");
        }
        if (!users[userToSuspend]) revert Unauthorized("User not registered");
        users[userToSuspend] = false;
        suspendedUsers[userToSuspend] = true;

        emit AccountSuspended(userToSuspend);
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && suspendedUsers[from]) {
            revert Unauthorized("User suspended");
        }
        if (to != address(0) && suspendedUsers[to]) {
            revert Unauthorized("User suspended");
        }
        return super._update(to, tokenId, auth);
    }

    //TERMINAR
    function withdrawFundsOwner(uint256 _eventId)
        external
        onlyOwner
        eventExists(_eventId)
        onlyEventOrganizer(_eventId)
    { }

    //TERMINAR RESELLS
    function resellTicket (uint256 tokenId, address to) external {}

    receive() external payable { }
}
