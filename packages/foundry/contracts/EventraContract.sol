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
        uint256 eventId;
        address organizer; 
        uint32 ticketsSold; 
        uint8 maxTicketsPerAddress;
        uint8 maxNumberOfOwners;
        EventState eventState;
    }

    struct Ticket {
        uint256 eventId;
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

    error Unauthorized(string argument);

    error TransferFailed(address to, uint256 amount, string argument);
    error TicketTransferFailed(address to, uint256 tokenId, string argument);

    error NotFundsToWithdraw(address organizer, uint256 eventId, string argument);
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
    uint256[] public eventsIds;
    uint256[] public ticketsInResell;
    

    mapping(address => bool) public users;
    mapping(address => bool) public suspendedUsers;
    mapping(address => uint256) public pendingRefunds;

    mapping(address => bool) public companies;
    mapping(address => uint256) public eventCompanyBalance;

    mapping(uint256 => Event) public events; // EventId => Event struct
    mapping(address => bool) public companyEvents; // Addr => Lista de EventId

    mapping(uint256 => uint256[]) public eventTickets; // EventId => Lista de TokenId - OTRA OPCION: codificar el eventId dentro del propio tokenId

    mapping(uint256 => Ticket) public tickets; // TokenId => Ticket struct.
    mapping(address => uint256[]) public userTickets; // User Address => Lista de TokenId vinculados al User Address.
    mapping(uint256 => uint256) public userTicketIndex; // TokenId => index del ticketId en el array userTickets
    mapping(address => mapping(uint256 => uint256)) public userEventTickets; // User Address => EventId => Numberof tickets for that event

    mapping(uint256 => uint256) public ticketResellPrice;  // If value is 0 => ticket is not in resell
    mapping(uint256 => uint256) public resellTicketIndex;  // TicketId => index del ticketId en el array ticketsInResell

    ////////////////
    /// Events /////
    ////////////////

    event UserRegistered(address indexed user);
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
    event TicketFundsWithdrawn(uint256 indexed ticketId, string indexed argument, uint256 amount);


    /////////////////
    /// Modifiers ///
    /////////////////

    modifier eventExists(uint256 _eventId) {
        if (events[_eventId].organizer == address(0)) {
            revert EventError(_eventId, "Event not found");
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
        }

        if (events[_eventId].eventState == EventState.Canceled) {
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

    ////////////////////////////
    ///  Internal Functions  ///
    ////////////////////////////

    function _deleteTicketFromUser(address _user, uint256 _ticket) internal returns (bool _ok) {
        uint256[] storage userList = userTickets[_user];
        uint256 len = userList.length;
        uint256 ticketIndex = userTicketIndex[_ticket];

        // Proteccion contra out of bounds
        if (ticketIndex >= len) return false;

        if (userList[ticketIndex] == _ticket) return false;

        userList[ticketIndex] = userList[len - 1];
        userTicketIndex[userList[len - 1]] = ticketIndex;
        userList.pop();

        delete userTicketIndex[_ticket]; // para mantener la limpieza
        return true;
        
    }

    function _deleteTicketFromResell(uint256 _ticketId) internal returns (bool) {
        uint256[] storage ticketsInResellIds = ticketsInResell;
        uint256 len = ticketsInResell.length;
        uint256 ticketIndex = resellTicketIndex[_ticketId];

        if (ticketIndex >= len) return false;

        if (ticketsInResellIds[ticketIndex] == _ticketId) return false;

        ticketsInResellIds[ticketIndex] = ticketsInResellIds[len - 1];
        resellTicketIndex[ticketsInResellIds[len - 1]] = ticketIndex;
        ticketsInResellIds.pop();

        delete resellTicketIndex[_ticketId]; // para mantener la limpieza
        return true;
        
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = _ownerOf(tokenId);
        if (from != address(0) && suspendedUsers[from]) {
            revert InvalidAction("User suspended");
        }
        if (to != address(0) && suspendedUsers[to]) {
            revert InvalidAction("User suspended");
        }
        return super._update(to, tokenId, auth);
    }    

    ///////////////////
    /// Functions /////
    ///////////////////

    function registerUser() external {
        if (suspendedUsers[msg.sender]) revert Unauthorized("Suspended user");

        users[msg.sender] = true;
        emit UserRegistered(msg.sender);
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
        if (companyEvents[msg.sender]) {
            revert InvalidAction("Company already has an event");
        }
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
        companyEvents[msg.sender] = true;

        emit EventCreated(eventId, _eventName, _ticketPrice, _eventDate);
    }


    function cancelEvent(uint256 _eventId)
        external
        eventExists(_eventId)
        onlyCompany(msg.sender)
        onlyActivedEvent(_eventId)
    {
        Event storage eventra = events[_eventId];
        eventra.eventState = EventState.Canceled;
        companyEvents[msg.sender] = false;

        uint256[] storage ticketsIds = eventTickets[_eventId];
        for (uint256 i = 0; i < ticketsIds.length; i++) {

            uint256 ticketId = ticketsIds[i];
            Ticket storage ticket = tickets[ticketId];

            if (ticket.ticketState == TicketState.Active || ticket.ticketState == TicketState.inResell) {
                bool wasInResell = ticket.ticketState == TicketState.inResell;
                ticket.ticketState = TicketState.Cancelled;

                if (wasInResell) {
                    ticketResellPrice[ticketId] = 0;
                    bool ok = _deleteTicketFromResell(ticketId);
                    if (!ok) revert TickectError(ticketId, "Ticket not found in resell list");
                }

                pendingRefunds[ticket.ticketUser] += eventra.ticketPrice;
                eventCompanyBalance[eventra.organizer] -= eventra.ticketPrice;
            }  
        }

        if (block.timestamp <= eventra.startSellDate - CANCEL_DEAD_LINE) {
            (bool ok,) = msg.sender.call{ value: EVENT_DEPOSIT }("");
            if (!ok) revert TransferFailed(msg.sender, EVENT_DEPOSIT, "Error refunding event deposit");
        }

        emit EventCanceled(_eventId, eventra.eventName, eventra.ticketPrice, eventra.eventDate);
    }



    function getEventStatistics(uint256 _eventId)
        external
        view
        eventExists(_eventId)
        onlyCompany(msg.sender)
        returns (uint256 eventBalance, uint32 ticketsSold, uint32 ticketsLeft, uint256 sellThroughRate)
    {
        Event storage eventra = events[_eventId];
        ticketsLeft = eventra.totalTicketNumber - eventra.ticketsSold;
        sellThroughRate = (eventra.ticketsSold * 100) / eventra.totalTicketNumber;

        return (eventCompanyBalance[msg.sender], eventra.ticketsSold, ticketsLeft, sellThroughRate);
    }

    


    function buyTicket(uint256 _eventId) external payable eventExists(_eventId) onlyActivedEvent(_eventId) onlyUser(msg.sender) {

        Event storage eventra = events[_eventId];

        if (eventra.eventState == EventState.SoldOut) {
            revert EventError(_eventId, "Event sold out");
        }
        if (block.timestamp > eventra.endSellDate || block.timestamp < eventra.startSellDate) {
            revert EventError(_eventId, "Sales closed");
        }
        
        uint256 amountToOwner = (eventra.ticketPrice * OWNER_COMMISSION) / 100;

        if (msg.value != eventra.ticketPrice + amountToOwner) {
            revert InvalidAmount(msg.value, eventra.ticketPrice + amountToOwner);
        }

        if (userEventTickets[msg.sender][_eventId] >= eventra.maxTicketsPerAddress) {
            revert InvalidAction("You reached the max number of tickets you can buy for this event.");
        }

        uint256 tokenId = nextTokenId;
        nextTokenId++;

        tickets[tokenId] =
            Ticket({ eventId: _eventId, ticketUser: msg.sender, numberOfOwners: 1, ticketState: TicketState.Active });

        eventTickets[_eventId].push(tokenId);
        userTickets[msg.sender].push(tokenId);
        userTicketIndex[tokenId] = userTickets[msg.sender].length - 1;
        userEventTickets[msg.sender][_eventId] += 1;
        eventra.ticketsSold += 1;

        if (eventra.ticketsSold == eventra.totalTicketNumber) {
            eventra.eventState = EventState.SoldOut;
            emit EventSoldOut(_eventId, eventra.eventName);
        }

        eventCompanyBalance[eventra.organizer] += msg.value - amountToOwner;
        eventCompanyBalance[owner()] += amountToOwner;

        _safeMint(msg.sender, tokenId);

        emit TicketSold(_eventId, tokenId, msg.sender, eventra.ticketPrice);
    }



    function buyTicketFromResell(uint256 _tokenId) external payable onlyUser(msg.sender) onlyActivedEvent(tickets[_tokenId].eventId) {
        Ticket storage ticket = tickets[_tokenId];
        if (ticket.numberOfOwners == 0) revert TickectError(_tokenId, "This ticket does not exist");
        if (ticket.ticketState != TicketState.inResell) revert TickectError(_tokenId, "Ticket is not in resell");

        uint256 resellPrice = ticketResellPrice[_tokenId];
        if (resellPrice == 0) revert InvalidArgument("Invalid ticket price");

        address seller = ticket.ticketUser;
        if (seller == msg.sender) revert TickectError(_tokenId, "You can't buy your own ticket");

        if (msg.value != resellPrice) revert InvalidAmount(msg.value, resellPrice);

        Event storage ev = events[ticket.eventId];

        if (block.timestamp > ev.endSellDate || block.timestamp < ev.startSellDate) {
            revert EventError(ev.eventId, "Sales closed");
        }

        if (userEventTickets[msg.sender][ticket.eventId] == ev.maxTicketsPerAddress) {
            revert TickectError(_tokenId, "You reached the max number of tickets you can buy for this event.");
        }

        if (ticket.numberOfOwners >= ev.maxNumberOfOwners) {
            revert TickectError(_tokenId, "Ticket reached the maximum number of owners.");
        }

        uint256 royalty = (resellPrice * ev.ticketRoyalty) / 100;
        uint256 amountToSeller = resellPrice - royalty;

        ticket.ticketUser = msg.sender;
        ticket.numberOfOwners += 1;
        ticket.ticketState = TicketState.Active;
        ticketResellPrice[_tokenId] = 0;

        bool ok = _deleteTicketFromResell(_tokenId);
        if (!ok) revert TickectError(_tokenId, "Ticket not found in resell list");

        bool ok2 = _deleteTicketFromUser(seller, _tokenId);
        if (!ok2) revert TickectError(_tokenId, "Error deleting ticket from user");
        userTickets[msg.sender].push(_tokenId);

        // actualizamos el indice del nuevo Ticket minteado
        userTicketIndex[_tokenId] = userTickets[msg.sender].length - 1;

        // actualizamos el numero de tickets que tiene cada usuario para ese evento
        userEventTickets[seller][ticket.eventId] -= 1;
        userEventTickets[msg.sender][ticket.eventId] += 1;

        eventCompanyBalance[ev.organizer] += royalty;

        _safeTransfer(seller, msg.sender, _tokenId);

        (bool sent,) = seller.call{ value: amountToSeller }("");
        if (!sent) revert TransferFailed(seller, amountToSeller, "Error transferring funds to seller");

        emit TicketSold(ticket.eventId, _tokenId, msg.sender, uint96(resellPrice));
    }



    function transferTicket(address _to, uint256 _ticketId) external onlyUser(msg.sender) onlyUser(_to) onlyActivedEvent(tickets[_ticketId].eventId) {

        Ticket storage ticket = tickets[_ticketId];
        if (ticket.ticketUser != msg.sender) revert Unauthorized("Wrong user");
        if (userEventTickets[_to][ticket.eventId] == events[ticket.eventId].maxTicketsPerAddress) {
            revert TicketTransferFailed(_to, _ticketId, "Destination reached the max number of tickets it can get for this event.");
        }
        if (ticket.ticketState != TicketState.Active) {
            revert TickectError(_ticketId, "Ticket is not active");
        }

        address seller = ticket.ticketUser;
        if (seller == msg.sender) revert TickectError(_ticketId, "You can't buy your own ticket");

        Event storage ev = events[ticket.eventId];

        if (ticket.numberOfOwners >= ev.maxNumberOfOwners) {
            revert TicketTransferFailed(_to, _ticketId, "Max number of owners reached for this ticket");
        }
        ticket.numberOfOwners += 1;
        tickets[_ticketId].ticketUser = _to;

        bool ok = _deleteTicketFromUser(msg.sender, _ticketId);
        if (!ok) revert TicketTransferFailed(_to, _ticketId, "Error deleting ticket from user");

        userTickets[_to].push(_ticketId);
        userTicketIndex[_ticketId] = userTickets[_to].length - 1;
        userEventTickets[_to][ticket.eventId] += 1;

        userEventTickets[msg.sender][ticket.eventId] -= 1;
        
        _safeTransfer(msg.sender, _to, _ticketId);
    }



    function putTicketInResell (uint256 _tokenId, uint256 _resellPrice) external onlyUser(msg.sender) onlyActivedEvent(tickets[_tokenId].eventId) {
        Ticket storage ticket = tickets[_tokenId];
        if (ticket.numberOfOwners == 0) revert TickectError(_tokenId, "This ticket does not exist");
        if (ticket.ticketUser != msg.sender) revert TickectError(_tokenId, "This ticket does not belong to you");

        if(ticketResellPrice[_tokenId] != 0) revert TickectError(_tokenId, "Ticket already in resell");

        if(_resellPrice == 0) revert InvalidArgument("Resell Price must be > 0");

        if(ticket.ticketState != TicketState.Active) revert TickectError(_tokenId, "The ticket is not active");

        Event storage ev = events[ticket.eventId];

        if (ticket.numberOfOwners >= ev.maxNumberOfOwners) revert TickectError(_tokenId, "You can't transfer the Ticket more. It reached the maximum number of owners.");

        ticket.ticketState = TicketState.inResell;
        ticketResellPrice[_tokenId] = _resellPrice;
        ticketsInResell.push(_tokenId);
        resellTicketIndex[_tokenId] = ticketsInResell.length - 1;

        emit TicketInResell(_tokenId, _resellPrice);
    }



    function removeTicketFromResell(uint256 _tokenId) external onlyUser(msg.sender) {
        Ticket storage ticket = tickets[_tokenId];
        if (ticket.numberOfOwners == 0) revert TickectError(_tokenId, "This ticket does not exist");
        if (ticket.ticketUser != msg.sender) revert TickectError(_tokenId, "This ticket does not belong to you");
        if (ticket.ticketState != TicketState.inResell) revert TickectError(_tokenId, "Ticket is not in resell");


        ticket.ticketState = TicketState.Active;
        ticketResellPrice[_tokenId] = 0;

        bool ok = _deleteTicketFromResell(_tokenId);
        if (!ok) revert TickectError(_tokenId, "Ticket not found in resell list");

        emit TicketRemovedFromResell(_tokenId);
    }

    

    function withdrawUserFunds(uint256 _ticketId) external onlyUser(msg.sender) { 
        Ticket storage ticket = tickets[_ticketId];

        if (ticket.ticketState != TicketState.Cancelled) {
            revert TickectError(_ticketId, "Ticket not cancelled");
        }

        uint256 amount = events[ticket.eventId].ticketPrice;
        if (pendingRefunds[msg.sender] == 0) revert NotFundsToWithdraw(msg.sender, _ticketId, "No funds available for withdrawal");

        ticket.ticketState = TicketState.Reimbursed;
        pendingRefunds[msg.sender] -= amount;

        (bool ok,) = msg.sender.call{ value: amount }("");
        if (!ok) revert TransferFailed(msg.sender, amount, "Error withdrawing event funds");

        emit TicketFundsWithdrawn(_ticketId, "Reimbursed ticket", amount);
    }



    function withdrawCompanyFunds(uint256 _eventId) 
        external 
        eventExists(_eventId) 
        onlyCompany(msg.sender) 
    {
        Event storage eventra = events[_eventId];
        if (block.timestamp < eventra.eventDate + CANCEL_DEAD_LINE) {
            revert EventError(_eventId, "Event not finished yet");
        }

        uint256 amount = eventCompanyBalance[msg.sender];
        if (amount == 0) revert NotFundsToWithdraw(msg.sender, _eventId, "No funds available for withdrawal");

        eventra.eventState = EventState.Finished;
        eventCompanyBalance[msg.sender] = 0;

        (bool ok,) = msg.sender.call{ value: amount }("");
        if (!ok) revert TransferFailed(msg.sender, amount, "Error withdrawing event funds");

        emit EventFundsWithdrawn(_eventId, eventra.eventName, amount);
    }



    function withdrawOwnerFunds()
        external
        onlyOwner
    { 
        uint256 amount = eventCompanyBalance[owner()];
        if (amount == 0) revert NotFundsToWithdrawOwner(msg.sender, "No funds available for withdrawal");
        
        eventCompanyBalance[owner()] = 0;

        (bool ok,) = msg.sender.call{ value: amount }("");
        if (!ok) revert TransferFailed(msg.sender, amount, "Error withdrawing owner funds");
    }



    function suspendAccount(address _userToSuspend) external onlyOwner {
        if (_userToSuspend == address(0)) {
            revert InvalidArgument("User not found");
        }
        if (!users[_userToSuspend]) revert InvalidAction("User not registered");
        users[_userToSuspend] = false;
        suspendedUsers[_userToSuspend] = true;

        emit AccountSuspended(_userToSuspend);
    }



    receive() external payable { }

    ////////////////////////////
    ///  Frontend Functions  ///
    ////////////////////////////

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

    function getTicketsInResell() external view returns (uint256[] memory) {
        return ticketsInResell;
    }

    
}
