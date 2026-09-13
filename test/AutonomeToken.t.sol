// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/AutonomeToken.sol";

contract AutonomeTokenTest is Test {
    AutonomeToken public atma;
    address public vault = address(0xAA);
    address public user = address(0xBB);

    uint256 internal userPrivateKey = 0xA11CE;
    address internal alice;

    function setUp() public {
        alice = vm.addr(userPrivateKey);
        atma = new AutonomeToken(vault);
    }

    function test_InitialSupplyAndCap() public view {
        assertEq(atma.totalSupply(), 100_000_000 * 1e18);
        assertEq(atma.balanceOf(vault), 100_000_000 * 1e18);
        assertEq(atma.owner(), vault);
    }

    function test_DeflationaryBurn() public {
        vm.startPrank(vault);
        atma.transfer(user, 1_000 * 1e18);
        vm.stopPrank();

        // Simulate a 5% fee burn on a task settlement
        vm.startPrank(user);
        atma.burn(50 * 1e18);
        vm.stopPrank();

        assertEq(atma.balanceOf(user), 950 * 1e18);
        assertEq(atma.totalSupply(), (100_000_000 * 1e18) - (50 * 1e18));
    }

    function test_EIP2612PermitGaslessApproval() public {
        uint256 amount = 500 * 1e18;
        uint256 deadline = block.timestamp + 1 days;

        // Construct EIP-712 Permit digest
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                alice,
                address(this),
                amount,
                atma.nonces(alice),
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", atma.DOMAIN_SEPARATOR(), structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);

        // Submit permit without alice needing gas
        atma.permit(alice, address(this), amount, deadline, v, r, s);

        assertEq(atma.allowance(alice, address(this)), amount);
    }
}