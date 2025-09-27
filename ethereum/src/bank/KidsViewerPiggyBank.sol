// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '@openzeppelin/contracts/access/Ownable.sol';

/**
 * @title KidsViewerPiggyBank
 * @dev Piggy bank contract for children's rewards and DeFi investments
 * @notice This contract manages individual child savings and AAVE investments
 */
contract KidsViewerPiggyBank is Ownable {
  // Events
  event RewardReceived(uint64 indexed personId, address indexed token, uint256 amount, uint256 timestamp);
  event WithdrawalRequested(
    uint64 indexed personId,
    address indexed token,
    uint256 amount,
    string reason,
    uint256 requestId,
    uint256 timestamp
  );
  event WithdrawalApproved(uint64 indexed personId, uint256 requestId, uint256 timestamp);
  event WithdrawalRejected(uint64 indexed personId, uint256 requestId, string reason, uint256 timestamp);
  event InvestmentMade(uint64 indexed personId, address indexed token, uint256 amount, address indexed aaveProduct, uint256 timestamp);
  event InvestmentRecovered(uint64 indexed personId, address indexed token, uint256 amount, uint256 timestamp);
  event ParentApprovalUpdated(address indexed parent, uint64 indexed personId, bool approved, uint256 timestamp);
  event InvestmentConfigUpdated(uint64 indexed personId, bool enabled, uint256 maxAmount, uint256 timestamp);
  event AaveProductApprovalUpdated(uint64 indexed personId, address indexed aaveProduct, bool approved, uint256 timestamp);

  // Structs
  struct WithdrawalRequest {
    uint64 personId;
    address token;
    uint256 amount;
    uint64 timestamp;
    bool approved;
    bool executed;
    string reason;
  }

  // State variables
  bool public paused;
  uint256 public nextRequestId;

  mapping(uint64 => mapping(address => uint256)) public personBalances; // personId => token => balance
  mapping(uint64 => mapping(address => uint256)) public personEarnings; // personId => token => earnings
  mapping(uint256 => WithdrawalRequest) public withdrawalRequests;
  mapping(uint64 => uint256) public personRequestIds; // personId => requestId
  mapping(address => mapping(uint64 => bool)) public parentApprovals; // parent => personId => approved
  mapping(uint64 => bool) public investmentConfigs; // personId => enabled
  mapping(uint64 => uint256) public maxInvestmentAmounts; // personId => maxAmount
  mapping(uint64 => uint256) public totalInvested; // personId => totalInvested
  mapping(uint64 => mapping(address => bool)) public aaveProductApprovals; // personId => aaveProduct => approved
  mapping(uint64 => bool) public personActive;

  // Modifiers
  modifier whenNotPaused() {
    require(!paused, 'KidsViewerPiggyBank: Paused');
    _;
  }

  modifier onlyParent(uint64 personId) {
    require(parentApprovals[msg.sender][personId], 'KidsViewerPiggyBank: Not parent');
    _;
  }

  modifier validAmount(uint256 amount) {
    require(amount > 0, 'KidsViewerPiggyBank: Amount > 0');
    _;
  }

  constructor() Ownable(msg.sender) {
    nextRequestId = 1;
  }

  /**
   * @dev Receive reward from vault contract
   * @param personId ID of the person
   * @param token Address of the token
   * @param amount Amount of reward
   */
  function receiveReward(uint64 personId, address token, uint256 amount) external whenNotPaused validAmount(amount) onlyParent(personId) {
    personBalances[personId][token] += amount;
    personEarnings[personId][token] += amount;

    emit RewardReceived(personId, token, amount, block.timestamp);
  }

  /**
   * @dev Request withdrawal (parent can call this for their child)
   * @param personId ID of the person
   * @param token Address of the token
   * @param amount Amount to withdraw
   * @param reason Reason for withdrawal
   */
  function requestWithdrawal(uint64 personId, address token, uint256 amount, string calldata reason) external whenNotPaused validAmount(amount) onlyParent(personId) {
    require(personBalances[personId][token] >= amount, 'KidsViewerPiggyBank: Insufficient');

    uint256 requestId = nextRequestId++;
    withdrawalRequests[requestId] = WithdrawalRequest({
      personId: personId,
      token: token,
      amount: amount,
      timestamp: uint64(block.timestamp),
      approved: false,
      executed: false,
      reason: reason
    });

    personRequestIds[personId] = requestId;

    emit WithdrawalRequested(personId, token, amount, reason, requestId, block.timestamp);
  }

  /**
   * @dev Approve withdrawal request (parent can call this)
   * @param requestId ID of the withdrawal request
   */
  function approveWithdrawal(uint256 requestId) external onlyOwner whenNotPaused {
    WithdrawalRequest storage request = withdrawalRequests[requestId];
    require(!request.approved, 'KidsViewerPiggyBank: Already approved');
    require(!request.executed, 'KidsViewerPiggyBank: Already executed');

    request.approved = true;
    personBalances[request.personId][request.token] -= request.amount;

    emit WithdrawalApproved(request.personId, requestId, block.timestamp);
  }

  /**
   * @dev Reject withdrawal request (parent can call this)
   * @param requestId ID of the withdrawal request
   * @param reason Reason for rejection
   */
  function rejectWithdrawal(uint256 requestId, string calldata reason) external whenNotPaused {
    WithdrawalRequest storage request = withdrawalRequests[requestId];
    require(!request.approved, 'KidsViewerPiggyBank: Already approved');
    require(!request.executed, 'KidsViewerPiggyBank: Already executed');

    request.executed = true;
    request.reason = reason;

    emit WithdrawalRejected(request.personId, requestId, reason, block.timestamp);
  }

  /**
   * @dev Invest in AAVE (parent can call this for their child)
   * @param personId ID of the person
   * @param token Address of the token
   * @param amount Amount to invest
   * @param aaveProduct Address of the AAVE product
   */
  function investInAave(uint64 personId, address token, uint256 amount, address aaveProduct) external whenNotPaused validAmount(amount) onlyParent(personId) {
    require(personBalances[personId][token] >= amount, 'KidsViewerPiggyBank: Insufficient');

    personBalances[personId][token] -= amount;

    emit InvestmentMade(personId, token, amount, aaveProduct, block.timestamp);
  }

  /**
   * @dev Recover all investments (parent can call this)
   * @param personId ID of the person
   * @param token Address of the token
   */
  function recoverAllInvestments(uint64 personId, address token) external onlyParent(personId) whenNotPaused {
    uint256 recoveredAmount = personBalances[personId][token];
    personBalances[personId][token] = 0;

    emit InvestmentRecovered(personId, token, recoveredAmount, block.timestamp);
  }

  /**
   * @dev Set parent approval for person
   * @param personId ID of the person
   * @param approved Whether to approve or revoke approval
   */
  function setParentApproval(uint64 personId, bool approved) external {
    parentApprovals[msg.sender][personId] = approved;
    emit ParentApprovalUpdated(msg.sender, personId, approved, block.timestamp);
  }

  /**
   * @dev Enable/disable investment for person (parent can call this)
   * @param personId ID of the person
   * @param enabled Whether to enable investment
   * @param maxAmount Maximum investment amount
   */
  function setInvestmentConfig(uint64 personId, bool enabled, uint256 maxAmount) external onlyParent(personId) {
    investmentConfigs[personId] = enabled;
    maxInvestmentAmounts[personId] = maxAmount;
    totalInvested[personId] = 0;

    emit InvestmentConfigUpdated(personId, enabled, maxAmount, block.timestamp);
  }

  /**
   * @dev Approve AAVE product for person (parent can call this)
   * @param personId ID of the person
   * @param aaveProduct Address of the AAVE product
   * @param approved Whether to approve or revoke approval
   */
  function setAaveProductApproval(uint64 personId, address aaveProduct, bool approved) external onlyParent(personId) {
    aaveProductApprovals[personId][aaveProduct] = approved;
    emit AaveProductApprovalUpdated(personId, aaveProduct, approved, block.timestamp);
  }

  /**
   * @dev Activate/deactivate person account
   * @param personId ID of the person
   * @param active Whether to activate or deactivate
   */
  function setPersonActive(uint64 personId, bool active) external onlyOwner {
    personActive[personId] = active;
  }

  /**
   * @dev Pause contract
   */
  function pause() external onlyOwner {
    paused = true;
  }

  /**
   * @dev Unpause contract
   */
  function unpause() external onlyOwner {
    paused = false;
  }

  /**
   * @dev Get person's token balance
   * @param personId ID of the person
   * @param token Address of the token
   * @return Balance amount
   */
  function getPersonBalance(uint64 personId, address token) external view returns (uint256) {
    return personBalances[personId][token];
  }

  /**
   * @dev Get person's earnings
   * @param personId ID of the person
   * @param token Address of the token
   * @return balance Balance amount
   * @return earnings Earnings amount
   */
  function getPersonEarnings(uint64 personId, address token) external view returns (uint256 balance, uint256 earnings) {
    return (personBalances[personId][token], personEarnings[personId][token]);
  }

  /**
   * @dev Get withdrawal request details
   * @param requestId ID of the request
   * @return request Withdrawal request details
   */
  function getWithdrawalRequest(uint256 requestId) external view returns (WithdrawalRequest memory) {
    return withdrawalRequests[requestId];
  }

  /**
   * @dev Get person's withdrawal requests
   * @param personId ID of the person
   * @return requestId Request ID
   */
  function getPersonWithdrawalRequests(uint64 personId) external view returns (uint256) {
    return personRequestIds[personId];
  }

  /**
   * @dev Get investment configuration for person
   * @param personId ID of the person
   * @return isEnabled Whether investment is enabled
   * @return maxInvestmentAmount Maximum investment amount
   * @return totalInvestedAmount Total amount invested
   */
  function getInvestmentConfig(
    uint64 personId
  ) external view returns (bool isEnabled, uint256 maxInvestmentAmount, uint256 totalInvestedAmount) {
    return (investmentConfigs[personId], maxInvestmentAmounts[personId], totalInvested[personId]);
  }

  /**
   * @dev Check if AAVE product is approved for person
   * @param personId ID of the person
   * @param aaveProduct Address of the AAVE product
   * @return Whether product is approved
   */
  function isAaveProductApproved(uint64 personId, address aaveProduct) external view returns (bool) {
    return aaveProductApprovals[personId][aaveProduct];
  }

  /**
   * @dev Check if parent is approved for person
   * @param parent Address of the parent
   * @param personId ID of the person
   * @return Whether parent is approved
   */
  function isParentApproved(address parent, uint64 personId) external view returns (bool) {
    return parentApprovals[parent][personId];
  }

  /**
   * @dev Check if person is active
   * @param personId ID of the person
   * @return Whether person is active
   */
  function isPersonActive(uint64 personId) external view returns (bool) {
    return personActive[personId];
  }
}
