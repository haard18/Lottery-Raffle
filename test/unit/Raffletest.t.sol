// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {deployRaffle} from "../../script/deployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/helperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract Raffletest is Test {
    /*Events */
    event enteredRaffle(address indexed player);
    Raffle raffle;
    HelperConfig helperconfig;
    address public PLAYER = makeAddr("player");
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gaslane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;
    uint256 deployerkey;
    uint256 public constant STARTING_BALANCE = 10 ether;

    function setUp() external {
        deployRaffle deployer = new deployRaffle();
        vm.deal(PLAYER, STARTING_BALANCE);
        (raffle, helperconfig) = deployer.run();
        (entranceFee, interval, vrfCoordinator, gaslane, , , , ) = helperconfig
            .activeNetworkConfig();
        (
            ,
            ,
            ,
            ,
            subscriptionId,
            callbackGasLimit,
            link,
            deployerkey
        ) = helperconfig.activeNetworkConfig();
    }

    function testRaffleinitializesOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    //ENTER RAFFLE TESTS
    function testRaffleRevertsNotpaidEntranceFee() public {
        vm.prank(PLAYER);
        //ACT
        vm.expectRevert(Raffle.Raffle__notEnoughEntranceFee.selector);
        raffle.enterRaffle();
    }

    function testRafflerecordsThePlayerEntering() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventonEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit enteredRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCannotEnterwhenCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performupKeep("");
        vm.expectRevert(Raffle.Raffle__notOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    //CHECKUPKEEP TESTS

    function testCheckUpkeepFalseifNotBalanceEn() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upKeepneeded, ) = raffle.checkUpKeep("");
        assert(!upKeepneeded);
    }

    function testCheckUpKeepifRafflenotOpen() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performupKeep("");
        (bool upKeepneeded, ) = raffle.checkUpKeep("");
        assert(!upKeepneeded);
    }

    function testUpkeepreturnsFalseforTime() public skipFork {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(20);
        vm.roll(block.number + 1);
        // console.log(lasttime);
        // console.log(blocktime);
        // raffle.performupKeep("");
        (bool upkeepn, ) = raffle.checkUpKeep("");
        assert(!upkeepn);
    }

    function testCheckUpkeepReturnsTrueWhenParametersGood() skipFork public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpKeep("");

        // Assert
        assert(upkeepNeeded);
    }

    ///performUPkeepTests

    function testperformupkeepRunsOnlyWhenCheckUpKeepisTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performupKeep("");
    }

    function testPerformUpkeepRevertsifCheckUpKeepsisFalse() public {
        uint256 currentBalance = 0;
        uint256 currentPlayers = 0;
        uint256 raffleState = 0;
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__upkeepNotNeeded.selector,
                currentBalance,
                currentPlayers,
                raffleState
            )
        );
        raffle.performupKeep("");
    }

    modifier RaffleEnteredandTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateandemitsReqID()
        public
        RaffleEnteredandTimePassed
    {
        //Act
        vm.recordLogs();
        raffle.performupKeep(""); //emitrequestid
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[0];
        Raffle.RaffleState rState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
    }

    ///FULLFILLRANDOMWORDS
    modifier skipFork() {
        if(block.chainid!=31337){
            return;
        }
        _;
    }
    function testFullfillRandomWordscanOnlybeCalledafterPerformUpkeep(
        uint256 randomRequestid
    ) public RaffleEnteredandTimePassed skipFork{
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestid,
            address(raffle)
        );
    }

    function testFulfillRandomwordsPicksWinnerandResetafterMoneySent()
        public
        RaffleEnteredandTimePassed
        skipFork
    {
        uint256 additionalEntrants = 5;
        uint256 startIndex = 1;
        uint256 price = entranceFee * (additionalEntrants + 1);
        for (uint256 i = startIndex; i < startIndex + additionalEntrants; i++) {
            address player = address(uint160(i));
            hoax(player, STARTING_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }
        vm.recordLogs();
        raffle.performupKeep(""); //emitrequestid
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        (uint256 previousTime, ) = raffle.getlastTimestamp();
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );
        (uint256 newTime, ) = raffle.getlastTimestamp();
        //assert
        // assert(uint256(raffle.getRaffleState())==0);
        // assert(raffle.getRecentWinner()!=address(0));
        // assert(uint256(raffle.getPlayerslength())==0);
        // assert(previousTime<newTime);
        console.log(raffle.getRecentWinner().balance);
        console.log(price + STARTING_BALANCE - entranceFee);
        assert(
            raffle.getRecentWinner().balance ==
                price + STARTING_BALANCE - entranceFee
        );
    }
}
