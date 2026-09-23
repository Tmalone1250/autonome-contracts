// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AutonomeNodeRegistry
 * @author Autonome Network
 * @notice Maintains an on-chain registry mapping ephemeral compute node
 *         addresses to the financial receiving vaults of the node operators.
 */
contract AutonomeNodeRegistry is Ownable {
    mapping(address => address) public nodeToVault;

    event NodeRegistered(address indexed ephemeralNode, address indexed operatorVault);

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Registers an ephemeral compute node to an operator vault.
     * @param ephemeralNode The public execution address of the node.
     * @param operatorVault The address of the vault receiving the rewards.
     *
     * @dev Enforces that only the operatorVault can register a node to itself,
     *      ensuring an operator can only map nodes to the wallet they control.
     */
    function registerNode(address ephemeralNode, address operatorVault) external {
        require(msg.sender == operatorVault, "Registry: unauthorized");
        require(ephemeralNode != address(0), "Registry: zero node address");
        require(operatorVault != address(0), "Registry: zero vault address");

        nodeToVault[ephemeralNode] = operatorVault;

        emit NodeRegistered(ephemeralNode, operatorVault);
    }
}
