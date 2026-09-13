// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Autonome Token ($ATMA)
 * @author Autonome Network
 * @notice Fixed-supply utility token powering DePIN compute nodes, 
 *         AI Agent intent settlement, and BDEX V3 POL on BOT Chain.
 */
contract AutonomeToken is ERC20, ERC20Burnable, ERC20Permit, Ownable {
    uint256 public constant MAX_SUPPLY = 100_000_000 * 10 ** 18; // 100M Hard Cap

    event InitialSupplyMinted(address indexed recipient, uint256 amount);

    constructor(
        address initialVault
    )
        ERC20("Autonome", "ATMA")
        ERC20Permit("Autonome")
        Ownable(initialVault)
    {
        require(initialVault != address(0), "ATMA: zero address vault");

        _mint(initialVault, MAX_SUPPLY);
        emit InitialSupplyMinted(initialVault, MAX_SUPPLY);
    }

    receive() external payable {
        revert("ATMA: Native BOT not accepted");
    }
}