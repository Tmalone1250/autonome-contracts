// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/AutonomeToken.sol";
import "../src/AutonomeSettlementEscrow.sol";
import "../src/AutonomeNodeRegistry.sol";

contract AutonomeSettlementEscrowTest is Test {
    AutonomeToken public atma;
    AutonomeNodeRegistry public registry;
    AutonomeSettlementEscrow public escrow;

    address public owner = address(this);
    address public polTreasury = address(0xAA1);
    address public validator = address(0xAA2);
    address public subAgent = address(0xBB1);
    address public computeNode = address(0xBB2);

    uint256 internal userPrivateKey = 0xA11CE;
    address internal alice;

    function setUp() public {
        alice = vm.addr(userPrivateKey);

        // Deploy Token
        atma = new AutonomeToken(owner);

        // Deploy Registry
        registry = new AutonomeNodeRegistry();

        // Deploy Escrow
        escrow = new AutonomeSettlementEscrow(address(atma), address(registry), polTreasury, validator);

        // Fund Alice with 10,000 ATMA
        atma.transfer(alice, 10_000 * 1e18);
    }

    function test_SettleTaskLifecycleAndSplits() public {
        bytes32 taskId = keccak256("task-intent-001");
        uint256 taskFee = 1_000 * 1e18; // 1,000 ATMA

        // Alice approves escrow and deposits
        vm.startPrank(alice);
        atma.approve(address(escrow), taskFee);
        escrow.depositIntent(taskId, taskFee);
        vm.stopPrank();

        assertEq(atma.balanceOf(address(escrow)), taskFee);

        uint256 initialTotalSupply = atma.totalSupply();

        address[] memory nodes = new address[](3);
        nodes[0] = address(0xBB2);
        nodes[1] = address(0xBB3);
        nodes[2] = address(0xBB4);

        address[] memory vaults = new address[](3);
        vaults[0] = address(0xCC2);
        vaults[1] = address(0xCC3);
        vaults[2] = address(0xCC4);

        // Register nodes
        vm.prank(vaults[0]);
        registry.registerNode(nodes[0], vaults[0]);
        
        vm.prank(vaults[1]);
        registry.registerNode(nodes[1], vaults[1]);

        vm.prank(vaults[2]);
        registry.registerNode(nodes[2], vaults[2]);

        // Validator settles the task
        vm.prank(validator);
        escrow.settleTask(taskId, subAgent, nodes);

        // Verify 70% Sub-agent payout (700 ATMA)
        assertEq(atma.balanceOf(subAgent), 700 * 1e18);

        // Verify 15% Compute Node payout goes to Vaults (150 ATMA total -> 50 ATMA each)
        assertEq(atma.balanceOf(vaults[0]), 50 * 1e18);
        assertEq(atma.balanceOf(vaults[1]), 50 * 1e18);
        assertEq(atma.balanceOf(vaults[2]), 50 * 1e18);

        // Verify 10% POL treasury allocation (100 ATMA)
        assertEq(atma.balanceOf(polTreasury), 100 * 1e18);

        // Verify 5% Burn (50 ATMA permanently destroyed)
        assertEq(atma.totalSupply(), initialTotalSupply - (50 * 1e18));
        assertEq(atma.balanceOf(address(escrow)), 0);
    }

    function test_DepositWithPermitGasless() public {
        bytes32 taskId = keccak256("task-intent-permit-002");
        uint256 taskFee = 500 * 1e18;
        uint256 deadline = block.timestamp + 1 hours;

        // Prepare EIP-712 Permit digest
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                alice,
                address(escrow),
                taskFee,
                atma.nonces(alice),
                deadline
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", atma.DOMAIN_SEPARATOR(), structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);

        // Relayer submits deposit on behalf of Alice with zero native gas from Alice
        vm.prank(validator);
        escrow.depositIntentWithPermit(taskId, alice, taskFee, deadline, v, r, s);

        assertEq(atma.balanceOf(address(escrow)), taskFee);
    }
}