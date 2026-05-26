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
        uint16 ticketRoyalty; 
        uint32 totalTicketNumber; 
        uint16 ticketRoyalty; 
        uint32 totalTicketNumber; 
        uint256 eventId;
        address organizer; 
        uint32 ticketsSold; 
        address organizer; 
        uint32 ticketsSold; 
        uint8 maxTicketsPerAddress;
        uint8 maxNumberOfOwners;
        EventState eventState;
    }

    struct Ticket {
        uint256 eventId;
        address ticketUser; 
        address ticketUser; 
        uint8 numberOfOwners;
        TicketState ticketState;
    }

    /////////////////
    /// Errors //////
    /////////////////

    error InvalidArgument(string argument);
    error InvalidAmount(uint256 sent, uint256 required);
    error InvalidAction(string argument);

    error EventError(uint256 eventId, string argument);
    error TickectError(uint256 tokenId, string argument);

    error InvalidAction(string argument);

    error EventError(uint256 eventId, string argument);
    error TickectError(uint256 tokenId, string argument);

    error Unauthorized(string argument);

    error TransferFailed(address to, uint256 amount, string argument);
    error TicketTransferFailed(address to, uint256 tokenId, string argument);


    error TransferFailed(address to, uint256 amount, string argument);
    error TicketTransferFailed(address to, uint256 tokenId, string argument);

    error NotFundsToWithdraw(address organizer, uint256 eventId);
    error NotFundsToWithdrawOwner(address owner, string argument);
    error NotFundsToWithdrawOwner(address owner, string argument);

    //////////////////////
    /// State Variables //
    //////////////////////

    uint256 public constant EVENT_DEPOSIT = 1 ether;
    uint16 public constant MINIMUM_ROYALTY = 10;
    uint16 public constant MAXIMUM_ROYALTY = 25;
    uint256 public constant CANCEL_DEAD_LINE = 1 days;

    uint256 public immutable OWNER_COMMISSION;

    uint256 public nextEventId;
    uint256 public nextTokenId; 
    uint256 public nextTokenId; 
    uint256[] public eventsIds;
    uint256 public ownerBalance; 
    uint256 public ownerBalance; 

    mapping(address => bool) public users;
    mapping(address => bool) public suspendedUsers;
    mapping(address => bool) public companies;
    mapping(address => uint256) public eventCompanyBalance;

    mapping(uint256 => Event) public events; // EventId => Event struct
    mapping(address => uint256[]) public companyEvents; // Addr => Lista de EventId

    mapping(uint256 => uint256[]) public eventTickets; // EventId => Lista de TokenId - OTRA OPCION: codificar el eventId dentro del propio tokenId

    mapping(uint256 => Ticket) public tickets; // TokenId => Ticket struct.
    mapping(address => uint256[]) public userTickets; // User Address => Lista de TokenId vinculados al User Address.

    // Variable for verifying if a ticket is in resell.
    // If value is 0 => ticket is not in resell
    mapping(uint256 => uint256) public ticketResellPrice;

    // Variable thought for frontend => for showing which tickets are on resell;
    uint256[] public ticketsInResell;

    ////////////////
    /// Events /////
    ////////////////

    event UserRegistered(address indexed user);
    event EventCompanyRegistered(string companyName, address companyAddress); 
    event EventCompanyRegistered(string companyName, address companyAddress); 
    event EventCreated(uint256 indexed eventId, string indexed eventName, uint96 ticketPrice, uint48 indexed eventDate);
    event EventCanceled(
        uint256 indexed eventId, string indexed eventName, uint96 ticketPrice, uint48 indexed eventDate
    );
    event EventFundsWithdrawn(uint256 indexed eventId, string indexed eventName, uint256 amount);
    event EventSoldOut(uint256 indexed eventId, string indexed eventName);
    event TicketSold(uint256 indexed eventId, uint256 indexed tokenId, address indexed buyer, uint96 price);
    event AccountSuspended(address indexed userSuspended);

    event TicketInResell(uint256 indexed ticketId, uint256 ticketPrice);
    event TicketRemovedFromResell (uint256 indexed ticketId);

    /////////////////
    /// Modifiers ///
    /////////////////

    modifier eventExists(uint256 _eventId) {
        if (events[_eventId].organizer == address(0)) {
            revert EventError(_eventId, "Event not found");
            revert EventError(_eventId, "Event not found");
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
            revert EventError(_eventId, "Event finished");
            revert EventError(_eventId, "Event finished");
        }

        if (events[_eventId].eventState == EventState.Canceled) {
            revert EventError(_eventId, "Event canceled");
            revert EventError(_eventId, "Event canceled");
        }
        _;
    }

    ///////////////////
    /// Constructor ///
    ///////////////////

    constructor(address _owner, uint256 _ticketBuyingComission) payable ERC721("Eventra Tickets", "EVTR") Ownable(_owner) {
        nextEventId = 1;
        nextTokenId = 1;
        OWNER_COMMISSION = _ticketBuyingComission;
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

    function buyTicket(uint256 _eventId) external payable eventExists(_eventId) onlyActivedEvent(_eventId) onlyUser(msg.sender) {

    function buyTicket(uint256 _eventId) external payable eventExists(_eventId) onlyActivedEvent(_eventId) onlyUser(msg.sender) {

        Event storage eventra = events[_eventId];

        if (eventra.eventState == EventState.SoldOut) {
            revert EventError(_eventId, "Event sold out");
            revert EventError(_eventId, "Event sold out");
        }
        if (block.timestamp > eventra.endSellDate || block.timestamp < eventra.startSellDate) {
            revert EventError(_eventId, "Sales closed");
            revert EventError(_eventId, "Sales closed");
        }
        
        uint256 amountToOwner = (eventra.ticketPrice * OWNER_COMMISSION) / 100;

        if (msg.value != eventra.ticketPrice + amountToOwner) {
            revert InvalidAmount(msg.value, eventra.ticketPrice + amountToOwner);
        }

        if (checkNumberOfTicketsOfUserForOneEvent(_eventId, msg.sender) == eventra.maxTicketsPerAddress) {
            revert InvalidAction("You reached the max number of tickets you can buy for this event.");
            revert InvalidAction("You reached the max number of tickets you can buy for this event.");
        }



        uint256 tokenId = nextTokenId;
        uint256 amountToOwner = (eventra.ticketPrice * TICKET_BUYING_COMISSION) / 100;

        uint256 amountToOwner = (eventra.ticketPrice * TICKET_BUYING_COMISSION) / 100;

        nextTokenId++;
        ownerBalance += amountToOwner;
        ownerBalance += amountToOwner;

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
        
        // We have track of how much of the contract's balance belongs to the owner
        eventCompanyBalance[owner()] += amountToOwner;

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

    function transferTicket(address _to, uint256 _ticketId) external onlyUser(msg.sender) onlyUser(_to) onlyActivedEvent(tickets[_ticketId].eventId) {
    function transferTicket(address _to, uint256 _ticketId) external onlyUser(msg.sender) onlyUser(_to) onlyActivedEvent(tickets[_ticketId].eventId) {

        Ticket storage ticket = tickets[_ticketId];
        if (ticket.ticketUser != msg.sender) revert Unauthorized("Wrong user");
        if (checkNumberOfTicketsOfUserForOneEvent(ticket.eventId, _to) == events[ticket.eventId].maxTicketsPerAddress) {
            revert TicketTransferFailed(_to, _ticketId, "Destination reached the max number of tickets it can get for this event.");
            revert TicketTransferFailed(_to, _ticketId, "Destination reached the max number of tickets it can get for this event.");
        }
        if (ticket.ticketState != TicketState.Active) {
            revert TickectError(_ticketId, "Ticket is not active");
            revert TickectError(_ticketId, "Ticket is not active");
        }

        Event storage ev = events[ticket.eventId];

        if (ticket.numberOfOwners >= ev.maxNumberOfOwners) {
            revert TicketTransferFailed(_to, _ticketId, "Max number of owners reached for this ticket");
            revert TicketTransferFailed(_to, _ticketId, "Max number of owners reached for this ticket");
        }
        ticket.numberOfOwners += 1;
        tickets[_ticketId].ticketUser = _to;

        bool ok = deleteTicketFromUser(msg.sender, _ticketId);
        if (!ok) revert TicketTransferFailed(_to, _ticketId, "Error deleting ticket from user");
        if (!ok) revert TicketTransferFailed(_to, _ticketId, "Error deleting ticket from user");
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

    function getTicketsInResell() external {

    }

    function getTicketsInResell() external {

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

        return (eventCompanyBalance[msg.sender], eventra.ticketsSold, ticketsLeft, sellThroughRate);
        return (eventCompanyBalance[msg.sender], eventra.ticketsSold, ticketsLeft, sellThroughRate);
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
            if (!ok) revert TransferFailed(msg.sender, EVENT_DEPOSIT, "Error refunding event deposit");
            if (!ok) revert TransferFailed(msg.sender, EVENT_DEPOSIT, "Error refunding event deposit");
        }

        emit EventCanceled(_eventId, eventra.eventName, eventra.ticketPrice, eventra.eventDate);
    }

    function withdrawFunds(uint256 _eventId) external eventExists(_eventId) onlyEventOrganizer(_eventId) {
        Event storage eventra = events[_eventId];
        if (block.timestamp < eventra.eventDate) {
            revert EventError(_eventId, "Event not finished yet");
            revert EventError(_eventId, "Event not finished yet");
        }

        uint256 amount = eventCompanyBalance[msg.sender];
        uint256 amount = eventCompanyBalance[msg.sender];
        if (amount == 0) revert NotFundsToWithdraw(msg.sender, _eventId);

        eventra.eventState = EventState.Finished;
        eventCompanyBalance[msg.sender] = 0;
        eventCompanyBalance[msg.sender] = 0;

        (bool ok,) = msg.sender.call{ value: amount }("");
        if (!ok) revert TransferFailed(msg.sender, amount, "Error withdrawing event funds");
        if (!ok) revert TransferFailed(msg.sender, amount, "Error withdrawing event funds");

        emit EventFundsWithdrawn(_eventId, eventra.eventName, amount);
    }

    function suspendAccount(address _userToSuspend) external onlyOwner {
        if (_userToSuspend == address(0)) {
    function suspendAccount(address _userToSuspend) external onlyOwner {
        if (_userToSuspend == address(0)) {
            revert InvalidArgument("User not found");
        }
        if (!users[_userToSuspend]) revert InvalidAction("User not registered");
        users[_userToSuspend] = false;
        suspendedUsers[_userToSuspend] = true;
        if (!users[_userToSuspend]) revert InvalidAction("User not registered");
        users[_userToSuspend] = false;
        suspendedUsers[_userToSuspend] = true;

        emit AccountSuspended(_userToSuspend);
        emit AccountSuspended(_userToSuspend);
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && suspendedUsers[from]) {
            revert InvalidAction("User suspended");
            revert InvalidAction("User suspended");
        }
        if (to != address(0) && suspendedUsers[to]) {
            revert InvalidAction("User suspended");
            revert InvalidAction("User suspended");
        }
        return super._update(to, tokenId, auth);
    }


    function withdrawFundsOwner()

    function withdrawFundsOwner()
        external
        onlyOwner
    { 
        uint256 amount = ownerBalance;
        if (amount == 0) revert NotFundsToWithdrawOwner(msg.sender, "No funds available for withdrawal");
        
        ownerBalance = 0;

        (bool ok,) = msg.sender.call{ value: amount }("");
        if (!ok) revert TransferFailed(msg.sender, amount, "Error withdrawing owner funds");
    }
    { 
        uint256 amount = ownerBalance;
        if (amount == 0) revert NotFundsToWithdrawOwner(msg.sender, "No funds available for withdrawal");
        
        ownerBalance = 0;

        (bool ok,) = msg.sender.call{ value: amount }("");
        if (!ok) revert TransferFailed(msg.sender, amount, "Error withdrawing owner funds");
    }

    //TERMINAR RESELLS
    // resell price is the price to pay for the buyer. IT IS NOT THE PRICE THE TICKET OWNER IS GOING TO GET (because of royalties)
    function putTicketInResell (uint256 tokenId, uint256 resellPrice) external onlyUser(msg.sender){
        Ticket storage ticket = tickets[tokenId];
        if (ticket.numberOfOwners == 0) revert TicketNotFound("This ticket does not exist");
        if (ticket.ticketUser != msg.sender) revert Unauthorized("This ticket does not belong to you");

        if(ticketResellPrice[tokenId] != 0) revert TicketAlreadyInResell(tokenId);

        if(resellPrice == 0) revert InvalidArgument("Resell Price must be > 0");

        if(ticket.ticketState != TicketState.Active) revert Unauthorized("The ticket is not active");

        Event storage ev = events[ticket.eventId];
        if(ev.eventState == EventState.Canceled || ev.eventState == EventState.Expired || ev.eventState == EventState.Finished) {
            revert InvalidEventState();
        }

        if (ticket.numberOfOwners == ev.maxNumberOfOwners) revert Unauthorized("You can't transfer the Ticket more. It reached the maximum number of owners.");

        ticket.ticketState = TicketState.inResell;
        ticketResellPrice[tokenId] = resellPrice;
        ticketsInResell.push(tokenId);

        emit TicketInResell(tokenId, resellPrice);
    }

    function removeTicketFromResell(uint256 tokenId) external onlyUser(msg.sender) {
        Ticket storage ticket = tickets[tokenId];
        if (ticket.numberOfOwners == 0) revert TicketNotFound("This ticket does not exist");
        if (ticket.ticketUser != msg.sender) revert Unauthorized("This ticket does not belong to you");
        if (ticket.ticketState != TicketState.inResell) revert InvalidTicketState();

        ticket.ticketState = TicketState.Active;
        ticketResellPrice[tokenId] = 0;

        bool ok = deleteTicketFromResell(tokenId);
        if (!ok) revert TicketNotFound("Ticket not found in resell list");

        emit TicketRemovedFromResell(tokenId);
    }

    // Aux function that deletes ticket _ticketId from the array ticketsInResell
    function deleteTicketFromResell(uint256 _ticketId) internal returns (bool) {
        uint256 len = ticketsInResell.length;
        for (uint256 i = 0; i < len; i++) {
            if (ticketsInResell[i] == _ticketId) {
                ticketsInResell[i] = ticketsInResell[len - 1];
                ticketsInResell.pop();
                return true;
            }
        }
        return false;
    }

    function buyTicketFromResell(uint256 tokenId) external payable onlyUser(msg.sender) {
        Ticket storage ticket = tickets[tokenId];
        if (ticket.numberOfOwners == 0) revert TicketNotFound("This ticket does not exist");
        if (ticket.ticketState != TicketState.inResell) revert InvalidTicketState();

        uint256 resellPrice = ticketResellPrice[tokenId];
        if (resellPrice == 0) revert InvalidTicketState();

        address seller = ticket.ticketUser;
        if (seller == msg.sender) revert Unauthorized("You can't buy your own ticket");

        if (msg.value != resellPrice) revert InvalidAmount(msg.value, resellPrice);

        Event storage ev = events[ticket.eventId];
        if (
            ev.eventState == EventState.Canceled || ev.eventState == EventState.Expired
                || ev.eventState == EventState.Finished
        ) {
            revert InvalidEventState();
        }
        if (block.timestamp >= ev.eventDate) revert EventFinished(ticket.eventId);

        if (checkNumberOfTicketsOfUserForOneEvent(ticket.eventId, msg.sender) == ev.maxTicketsPerAddress) {
            revert Unauthorized("You reached the max number of tickets you can buy for this event.");
        }

        if (ticket.numberOfOwners >= ev.maxNumberOfOwners) {
            revert InvalidAmountOfTicketOwners();
        }

        uint256 royalty = (resellPrice * ev.ticketRoyalty) / 100;
        uint256 amountToSeller = resellPrice - royalty;

        ticket.ticketUser = msg.sender;
        ticket.numberOfOwners += 1;
        ticket.ticketState = TicketState.Active;
        ticketResellPrice[tokenId] = 0;

        bool ok = deleteTicketFromResell(tokenId);
        if (!ok) revert TicketNotFound("Ticket not found in resell list");

        bool ok2 = deleteTicketFromUser(seller, tokenId);
        if (!ok2) revert TicketTransferFailed();
        userTickets[msg.sender].push(tokenId);

        eventCompanyBalance[ev.organizer] += royalty;

        (bool sent,) = seller.call{ value: amountToSeller }("");
        if (!sent) revert TransferFailed(seller, amountToSeller);

        _safeTransfer(seller, msg.sender, tokenId);

        emit TicketSold(ticket.eventId, tokenId, msg.sender, uint96(resellPrice));
    }

    receive() external payable { }
}
