// SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;
import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./helperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperconfig = new HelperConfig();
        (, , address vrfCoordinator, , , , , uint256 deployerkey) = helperconfig
            .activeNetworkConfig();
        return createSubscription(vrfCoordinator, deployerkey);
    }

    function createSubscription(
        address vrfCoordinator,
        uint256 deployerkey
    ) public returns (uint64) {
        console.log("Creating subscription on chainid", block.chainid);
        vm.startBroadcast(deployerkey);
        uint64 subid = VRFCoordinatorV2Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("The subscription id= ", subid);
        return subid;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperconfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subid,
            ,
            address link,
            uint256 deployerkey
        ) = helperconfig.activeNetworkConfig();
        fundSubscription(vrfCoordinator, subid, link,deployerkey);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subid,
        address link,
        uint256 deployerkey
    ) public {
        console.log("Funding Subscription:", subid);
        console.log("Using vrfcordinator", vrfCoordinator);
        console.log("On chainid0", link);
        if (block.chainid == 31337) {
            vm.startBroadcast(deployerkey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subid,
                FUND_AMOUNT
            );

            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerkey);
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subid)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerusingConfig(address raffle) public {
        HelperConfig helperconfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subid,
            ,
            ,
            uint256 deployerkey
        ) = helperconfig.activeNetworkConfig();
        addConsumer(raffle, subid, vrfCoordinator, deployerkey);
    }

    function addConsumer(
        address raffle,
        uint64 subid,
        address vrfCoordinator,
        uint256 deployerkey
    ) public {
        console.log("Adding Consumer:", raffle);
        console.log("Using vrfCOordinator", vrfCoordinator);
        console.log("on chain id", block.chainid);
        vm.startBroadcast(deployerkey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subid, raffle);
        vm.stopBroadcast();
    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerusingConfig(raffle);
    }
}
