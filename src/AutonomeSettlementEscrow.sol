// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./AutonomeToken.sol";

/**
 * @title AutonomeSettlementEscrow
 * @author Autonome Network
 * @notice Escrows task fees and programmatically settles rewards across
 *         sub-agents, compute nodes, BDEX POL, and deflationary burns.
 */
contract AutonomeSettlementEscrow is Ownable, ReentrancyGuard {
    AutonomeToken public immutable atmaToken;

    // Protocol addresses
    address public polTreasury; // Receives the 10% POL allocation for BDEX V3
    address public validator;   // Orchestrator backend authorized to verify proofs

    // Fee Split Basis Points (Total = 10,000 bps / 100%)
    uint256 public constant SUB_AGENT_BPS = 7000;  // 70%
    uint256 public constant COMPUTE_NODE_BPS = 1500; // 15%
    uint256 public constant POL_BPS = 1000;         // 10%
    uint256 public constant BURN_BPS = 500;         // 5%

    enum TaskStatus { NonExistent, Escrowed, Settled, Refunded }

    struct IntentTask {
        address user;
        uint256 amount;
        TaskStatus status;
    }

    mapping(bytes32 => IntentTask) public tasks;

    event TaskEscrowed(bytes32 indexed taskId, address indexed user, uint256 amount);
    event TaskSettled(
        bytes32 indexed taskId,
        address indexed subAgent,
        address indexed computeNode,
        uint256 subAgentReward,
        uint256 nodeReward,
        uint256 polAllocation,
        uint256 burnedAmount
    );
    event TaskRefunded(bytes32 indexed taskId, address indexed user, uint256 amount);
    event PolTreasuryUpdated(address indexed newTreasury);
    event ValidatorUpdated(address indexed newValidator);

    modifier onlyValidator() {
        require(msg.sender == validator, "Escrow: caller is not validator");
        _;
    }

    constructor(
        address _atmaToken,
        address _polTreasury,
        address _validator
    ) Ownable(msg.sender) {
        require(_atmaToken != address(0), "Escrow: zero token");
        require(_polTreasury != address(0), "Escrow: zero pol treasury");
        require(_validator != address(0), "Escrow: zero validator");

        atmaToken = AutonomeToken(payable(_atmaToken));
        polTreasury = _polTreasury;
        validator = _validator;
    }

    /**
     * @notice Escrows intent task fee using standard allowance.
     */
    function depositIntent(bytes32 taskId, uint256 amount) external nonReentrant {
        _depositIntent(taskId, msg.sender, amount);
    }

    /**
     * @notice Escrows intent task fee using EIP-2612 Permit for gasless meta-transactions.
     */
    function depositIntentWithPermit(
        bytes32 taskId,
        address user,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        // Execute the gasless permit approval
        atmaToken.permit(user, address(this), amount, deadline, v, r, s);
        _depositIntent(taskId, user, amount);
    }

    function _depositIntent(bytes32 taskId, address user, uint256 amount) internal {
        require(tasks[taskId].status == TaskStatus.NonExistent, "Escrow: task already exists");
        require(amount > 0, "Escrow: amount zero");

        tasks[taskId] = IntentTask({
            user: user,
            amount: amount,
            status: TaskStatus.Escrowed
        });

        require(atmaToken.transferFrom(user, address(this), amount), "Escrow: transfer failed");

        emit TaskEscrowed(taskId, user, amount);
    }

    /**
     * @notice Settles a completed intent task, enforcing the 70/15/10/5 distribution.
     * @param taskId Unique identifier for the user intent.
     * @param subAgent Address of the community sub-agent developer/worker.
     * @param computeNode Address of the DePIN node runner hosting the inference.
     */
    function settleTask(
        bytes32 taskId,
        address subAgent,
        address computeNode
    ) external onlyValidator nonReentrant {
        IntentTask storage task = tasks[taskId];
        require(task.status == TaskStatus.Escrowed, "Escrow: task not escrowed");
        require(subAgent != address(0), "Escrow: zero subAgent");
        require(computeNode != address(0), "Escrow: zero computeNode");

        task.status = TaskStatus.Settled;
        uint256 totalAmount = task.amount;

        // Calculate splits
        uint256 subAgentReward = (totalAmount * SUB_AGENT_BPS) / 10000;
        uint256 nodeReward = (totalAmount * COMPUTE_NODE_BPS) / 10000;
        uint256 polAllocation = (totalAmount * POL_BPS) / 10000;
        uint256 burnedAmount = totalAmount - (subAgentReward + nodeReward + polAllocation); // Remainder (~5%)

        // Disburse tokens
        require(atmaToken.transfer(subAgent, subAgentReward), "Escrow: sub-agent transfer failed");
        require(atmaToken.transfer(computeNode, nodeReward), "Escrow: node transfer failed");
        require(atmaToken.transfer(polTreasury, polAllocation), "Escrow: POL transfer failed");
        
        // Native deflationary burn
        atmaToken.burn(burnedAmount);

        emit TaskSettled(
            taskId,
            subAgent,
            computeNode,
            subAgentReward,
            nodeReward,
            polAllocation,
            burnedAmount
        );
    }

    /**
     * @notice Refunds an unfulfilled task back to the user.
     */
    function refundTask(bytes32 taskId) external onlyValidator nonReentrant {
        IntentTask storage task = tasks[taskId];
        require(task.status == TaskStatus.Escrowed, "Escrow: task not escrowed");

        task.status = TaskStatus.Refunded;
        require(atmaToken.transfer(task.user, task.amount), "Escrow: refund failed");

        emit TaskRefunded(taskId, task.user, task.amount);
    }

    // --- Admin Configuration ---

    function setPolTreasury(address _polTreasury) external onlyOwner {
        require(_polTreasury != address(0), "Escrow: zero address");
        polTreasury = _polTreasury;
        emit PolTreasuryUpdated(_polTreasury);
    }

    function setValidator(address _validator) external onlyOwner {
        require(_validator != address(0), "Escrow: zero address");
        validator = _validator;
        emit ValidatorUpdated(_validator);
    }
}