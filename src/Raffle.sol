// SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions
/**
 * @title Sample Raffle contract
 * @author Haard Solanki
 * @notice this contract is to create a sample raffle
 * @dev Implements Chainlink vrf2
 */

contract Raffle is VRFConsumerBaseV2 {
    //errors

    error Raffle__notEnoughEntranceFee();
    error Raffle__transferFailed();
    error Raffle__notOpen();
    error Raffle__upkeepNotNeeded(
        uint256 currentBalance,
        uint256 numPlayers,
        uint256 raffstate
    );
    // type-declaration
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    //variable declarations

    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    uint private immutable i_interval;
    uint private s_lastTimeStamp;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gaslane;
    uint64 private immutable i_subscriptionId;
    address private s_recentWinner;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private constant NO_OF_WORDS = 1;
    RaffleState private s_rafflestate;

    //constructor
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gaslane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gaslane = gaslane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_rafflestate = RaffleState.OPEN;
    }

    //Events
    event enteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    function enterRaffle() external payable {
        // require(msg.value>=i_entranceFee,"Not enough Entrance fee");
        if (msg.value < i_entranceFee) {
            revert Raffle__notEnoughEntranceFee();
        }
        if (s_rafflestate != RaffleState.OPEN) {
            revert Raffle__notOpen();
        }
        s_players.push(payable(msg.sender));
        emit enteredRaffle(msg.sender);
    }

    //this function should tell when the winner must be picked
    /**
     * @dev This function is chainlink automation nodes call, follong should be true for this to be true
     * 1. the time interval has been passed between raffle runs
     * 2. The raffle is in open state.
     * 3. The contract has ETH(players)
     * 4. The subscription is funded with Link
     */

    function checkUpKeep(
        bytes memory /*checkData*/
    ) public view returns (bool upKeepNeeded, bytes memory /*performdata*/) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = RaffleState.OPEN == s_rafflestate;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upKeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upKeepNeeded, "0x0");
    }

    function performupKeep(bytes calldata /*performdata */) external {
        //    we neeed this to be called automatically
        (bool upKeepNeeded, ) = checkUpKeep("");
        if (!upKeepNeeded) {
            revert Raffle__upkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_rafflestate)
            );
        }

        s_rafflestate = RaffleState.CALCULATING;
        uint256 requestId=i_vrfCoordinator.requestRandomWords(
            i_gaslane, //gas lane
            i_subscriptionId, //id to fund the chainlink node
            REQUEST_CONFIRMATION, //no of block conf for no to be random
            i_callbackGasLimit, //limit the gasspend
            NO_OF_WORDS //no of random words
        );
        emit RequestedRaffleWinner(requestId);
    }

    //CEI Checks=>Effects=>Interactions
    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexofWinner = randomWords[0] % s_players.length;
        address payable winner = s_players[indexofWinner];
        s_recentWinner = winner;
        s_rafflestate = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        (bool success, ) = s_recentWinner.call{value: address(this).balance}(
            ""
        );
        if (!success) {
            revert Raffle__transferFailed();
        }
        emit WinnerPicked(winner);
    }

    // GetterFunction
    function getEntrancefee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_rafflestate;
    }

    function getPlayer(uint256 playerIndex) external view returns (address) {
        return s_players[playerIndex];
    }
    function getPlayerslength() external view returns(uint256){
        return s_players.length;
    }
    function getlastTimestamp() external view returns(uint,uint){
        return (s_lastTimeStamp,i_interval);
    }
    function getRecentWinner() external view returns(address){
        return s_recentWinner;
    }
}
