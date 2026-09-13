// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/AutonomeSettlementEscrow.sol";

contract DeployEscrowScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        // Load contract constructor parameters from .env
        address atmaAddress = vm.envAddress("ATMA_TOKEN_ADDRESS");
        
        // Defaults to deployer address if not explicitly configured
        address polTreasury = vm.envOr("POL_TREASURY_ADDRESS", deployerAddress);
        address validator = vm.envOr("VALIDATOR_ADDRESS", deployerAddress);

        console.log("--- Deploying AutonomeSettlementEscrow ---");
        console.log("Deployer / Admin :", deployerAddress);
        console.log("ATMA Token       :", atmaAddress);
        console.log("POL Treasury     :", polTreasury);
        console.log("Validator        :", validator);

        vm.startBroadcast(deployerPrivateKey);

        AutonomeSettlementEscrow escrow = new AutonomeSettlementEscrow(
            atmaAddress,
            polTreasury,
            validator
        );

        vm.stopBroadcast();

        console.log("==========================================");
        console.log("AutonomeSettlementEscrow Deployed Successfully!");
        console.log("Contract Address :", address(escrow));
        console.log("==========================================");
    }
}