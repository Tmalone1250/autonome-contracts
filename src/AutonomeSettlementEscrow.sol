// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./AutonomeToken.sol";
import "./AutonomeNodeRegistry.sol";

/**
 * @title AutonomeSettlementEscrow
 * @author Autonome Network
 * @notice Escrows task fees and programmatically settles rewards across
 *         sub-agents, compute nodes, BDEX POL, and deflationary burns.
 */
contract AutonomeSettlementEscrow is Ownable, ReentrancyGuard {
    AutonomeToken public immutable atmaToken;
    AutonomeNodeRegistry public registry;

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
        address indexed subAgentVault,
        address[] computeNodes,
        uint256 subAgentReward,
        uint256 totalNodeRewardPaid,
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
        address _registry,
        address _polTreasury,
        address _validator
    ) Ownable(msg.sender) {
        require(_atmaToken != address(0), "Escrow: zero token");
        require(_registry != address(0), "Escrow: zero registry");
        require(_polTreasury != address(0), "Escrow: zero pol treasury");
        require(_validator != address(0), "Escrow: zero validator");

        atmaToken = AutonomeToken(payable(_atmaToken));
        registry = AutonomeNodeRegistry(_registry);
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
     * @param subAgentVault Address of the community sub-agent developer/worker vault.
     * @param computeNodes Array of DePIN node runner verification addresses.
     */
    function settleTask(
        bytes32 taskId,
        address subAgentVault,
        address[] calldata computeNodes
    ) external onlyValidator nonReentrant {
        IntentTask storage task = tasks[taskId];
        require(task.status == TaskStatus.Escrowed, "Escrow: task not escrowed");
        require(subAgentVault != address(0), "Escrow: zero subAgentVault");
        require(computeNodes.length > 0, "Escrow: zero computeNodes");
        require(computeNodes.length <= 25, "Escrow: batch limit exceeded");

        task.status = TaskStatus.Settled;
        uint256 totalAmount = task.amount;

        // Calculate splits
        uint256 subAgentReward = (totalAmount * SUB_AGENT_BPS) / 10000;
        uint256 totalNodeReward = (totalAmount * COMPUTE_NODE_BPS) / 10000;
        uint256 polAllocation = (totalAmount * POL_BPS) / 10000;
        
        uint256 nodeRewardPerNode = totalNodeReward / computeNodes.length;
        
        uint256 nodesPaid = 0;

        // Disburse tokens
        require(atmaToken.transfer(subAgentVault, subAgentReward), "Escrow: sub-agent transfer failed");
        
        for (uint256 i = 0; i < computeNodes.length; i++) {
            address operatorVault = registry.nodeToVault(computeNodes[i]);
            if (operatorVault != address(0)) {
                require(atmaToken.transfer(operatorVault, nodeRewardPerNode), "Escrow: node transfer failed");
                nodesPaid++;
            }
        }
        
        uint256 totalNodeRewardPaid = nodeRewardPerNode * nodesPaid;
        // Unregistered nodes' shares get routed into the deflationary burn
        uint256 burnedAmount = totalAmount - (subAgentReward + totalNodeRewardPaid + polAllocation);

        require(atmaToken.transfer(polTreasury, polAllocation), "Escrow: POL transfer failed");
        
        // Native deflationary burn
        atmaToken.burn(burnedAmount);

        emit TaskSettled(
            taskId,
            subAgentVault,
            computeNodes,
            subAgentReward,
            totalNodeRewardPaid,
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

    function setRegistry(address _registry) external onlyOwner {
        require(_registry != address(0), "Escrow: zero address");
        registry = AutonomeNodeRegistry(_registry);
    }

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