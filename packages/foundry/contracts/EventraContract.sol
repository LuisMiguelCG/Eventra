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

    struct Event {

        bytes32 eventName;
        string eventDescription;
        uint256 ticketPrice;
        uint256 startSellDate;
        uint256 endSellDate;
        uint48 eventDate;
        uint256 ticketRoyalty;
        uint256 totalTicketNumber;
    }


    uint256 public nextEventId;

    uint256 public constant EVENT_DEPOSIT = 1 ether;
    uint16 public constant MINIMUM_ROYALTY = 10;
    uint16 public constant MAXIMUM_ROYALTY = 25;


    ////////////////
    /// Events /////
    ////////////////



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
        uint256 _ticketPrice,
        uint256 _startSellDate,
        uint256 _endSellDate,
        uint48 _eventDate,
        uint256 _ticketRoyalty,
        uint256 _totalTicketNumber
    ) external payable {}
    function viewStatistics(){}
    function cancelEvent(){}
    function withdrawFounds(){}


    function suspendAccount() onlyOwner {}


    receive() external payable { }
}
