// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/AutonomeToken.sol";

contract DeployATMAScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("Deploying Autonome ($ATMA) with:", deployerAddress);

        vm.startBroadcast(deployerPrivateKey);

        // Initial vault set to deployer address (can be changed to multisig later)
        AutonomeToken atma = new AutonomeToken(deployerAddress);

        vm.stopBroadcast();

        console.log("Autonome ($ATMA) Deployed at:", address(atma));
        console.log("Total Supply:", atma.totalSupply() / 1e18, "ATMA");
    }
}