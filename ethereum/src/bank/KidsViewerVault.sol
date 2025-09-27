// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '@openzeppelin/contracts/access/Ownable.sol';

/**
 * @title KidsViewerVault
 * @dev Vault contract for parent deposits and reward distribution management
 * @notice This contract manages the reward pool and enforces daily reward limits per child
 */
contract KidsViewerVault is Ownable {
  // Events
  event Deposit(address indexed caller, address indexed token, uint256 amount, uint256 timestamp);
  event Withdraw(address indexed caller, address indexed token, uint256 amount, uint256 timestamp);
  event RewardDistributed(address indexed child, address indexed token, uint256 amount, uint256 timestamp);
  event DailyLimitUpdated(address indexed child, address indexed token, uint256 newLimit, uint256 timestamp);
  event ParentAuthorized(address indexed parent, address indexed child, bool authorized, uint256 timestamp);

  // State variables
  bool public paused;
  uint256 public maxDailyLimit;
  uint256 public minDailyLimit;

  mapping(address => bool) public parentActive;
  mapping(address => mapping(address => bool)) public parentChildren; // parent => child => authorized
  mapping(address => mapping(address => uint256)) public parentBalances; // parent => token => balance
  mapping(address => uint256) public childDailyLimit;
  mapping(address => uint256) public childDailyUsed;
  mapping(address => uint64) public childLastReset;
  mapping(address => bool) public childActive;
  mapping(address => bool) public supportedTokens;
  mapping(address => uint256) public totalVaultBalances;

  // Modifiers
  modifier whenNotPaused() {
    require(!paused, 'KidsViewerVault: Paused');
    _;
  }

  modifier onlyParent() {
    require(parentActive[msg.sender], 'KidsViewerVault: Only parent');
    _;
  }

  modifier onlyAuthorizedChild(address child) {
    require(parentChildren[msg.sender][child], 'KidsViewerVault: Not authorized');
    _;
  }

  modifier onlySupportedToken(address token) {
    require(supportedTokens[token], 'KidsViewerVault: Not supported');
    _;
  }

  modifier validAmount(uint256 amount) {
    require(amount > 0, 'KidsViewerVault: Amount > 0');
    _;
  }

  constructor(uint256 _maxLimit, uint256 _minLimit) Ownable(msg.sender) {
    maxDailyLimit = _maxLimit;
    minDailyLimit = _minLimit;
  }

  /**
   * @dev Add a supported token to the vault
   * @param token Address of the ERC20 token
   */
  function addSupportedToken(address token) external onlyOwner {
    supportedTokens[token] = true;
  }

  /**
   * @dev Remove a supported token from the vault
   * @param token Address of the ERC20 token
   */
  function removeSupportedToken(address token) external onlyOwner {
    supportedTokens[token] = false;
  }

  /**
   * @dev Register a parent and activate their account
   * @param parent Address of the parent
   */
  function registerParent(address parent) external onlyOwner {
    parentActive[parent] = true;
  }

  /**
   * @dev Authorize a child for a parent
   * @param child Address of the child
   * @param authorized Whether to authorize or revoke authorization
   */
  function authorizeChild(address child, bool authorized) external onlyParent {
    parentChildren[msg.sender][child] = authorized;
    emit ParentAuthorized(msg.sender, child, authorized, block.timestamp);
  }

  /**
   * @dev Set daily reward limit for a child
   * @param child Address of the child
   * @param token Address of the token
   * @param dailyLimit Daily reward limit in token units
   */
  function setDailyRewardLimit(
    address child,
    address token,
    uint256 dailyLimit
  ) external onlyParent onlyAuthorizedChild(child) onlySupportedToken(token) {
    require(dailyLimit >= minDailyLimit, 'KidsViewerVault: Limit too low');
    require(dailyLimit <= maxDailyLimit, 'KidsViewerVault: Limit too high');

    childDailyLimit[child] = dailyLimit;
    emit DailyLimitUpdated(child, token, dailyLimit, block.timestamp);
  }

  /**
   * @dev Deposit tokens to the vault (only parents)
   * @param token Address of the ERC20 token
   * @param amount Amount to deposit
   */
  function deposit(address token, uint256 amount) external onlyParent onlySupportedToken(token) validAmount(amount) whenNotPaused {
    parentBalances[msg.sender][token] += amount;
    totalVaultBalances[token] += amount;

    emit Deposit(msg.sender, token, amount, block.timestamp);
  }

  /**
   * @dev Withdraw tokens from the vault (only parents)
   * @param token Address of the ERC20 token
   * @param amount Amount to withdraw
   */
  function withdraw(address token, uint256 amount) external onlyParent onlySupportedToken(token) validAmount(amount) whenNotPaused {
    require(parentBalances[msg.sender][token] >= amount, 'KidsViewerVault: Insufficient');

    parentBalances[msg.sender][token] -= amount;
    totalVaultBalances[token] -= amount;

    emit Withdraw(msg.sender, token, amount, block.timestamp);
  }

  /**
   * @dev Distribute reward to a child (only parents)
   * @param child Address of the child
   * @param token Address of the token
   * @param amount Amount to distribute as reward
   */
  function distributeReward(
    address child,
    address token,
    uint256 amount
  ) external onlyParent onlyAuthorizedChild(child) onlySupportedToken(token) validAmount(amount) {
    require(childActive[child], 'KidsViewerVault: Not active');

    // Reset daily usage if it's a new day
    if (block.timestamp - childLastReset[child] >= 86400) {
      childDailyUsed[child] = 0;
      childLastReset[child] = uint64(block.timestamp);
    }

    require(childDailyUsed[child] + amount <= childDailyLimit[child], 'KidsViewerVault: Limit exceeded');
    require(parentBalances[msg.sender][token] >= amount, 'KidsViewerVault: Insufficient');

    parentBalances[msg.sender][token] -= amount;
    childDailyUsed[child] += amount;

    emit RewardDistributed(child, token, amount, block.timestamp);
  }

  /**
   * @dev Activate/deactivate a child
   * @param child Address of the child
   * @param active Whether to activate or deactivate
   */
  function setChildActive(address child, bool active) external onlyParent onlyAuthorizedChild(child) {
    childActive[child] = active;
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
   * @dev Emergency withdraw function for owner
   * @param token Address of the token
   * @param amount Amount to withdraw
   */
  function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
    emit Withdraw(msg.sender, token, amount, block.timestamp);
  }

  /**
   * @dev Get parent's token balance in vault
   * @param parent Address of the parent
   * @param token Address of the token
   * @return Balance amount
   */
  function getParentBalance(address parent, address token) external view returns (uint256) {
    return parentBalances[parent][token];
  }

  /**
   * @dev Get child's reward configuration
   * @param child Address of the child
   * @return dailyRewardLimit Daily reward limit
   * @return dailyRewardUsed Amount used today
   * @return lastResetDate Last reset date
   * @return isActive Whether child is active
   */
  function getChildConfig(
    address child
  ) external view returns (uint256 dailyRewardLimit, uint256 dailyRewardUsed, uint64 lastResetDate, bool isActive) {
    return (childDailyLimit[child], childDailyUsed[child], childLastReset[child], childActive[child]);
  }

  /**
   * @dev Check if parent is authorized for child
   * @param parent Address of the parent
   * @param child Address of the child
   * @return Whether parent is authorized
   */
  function isParentAuthorized(address parent, address child) external view returns (bool) {
    return parentChildren[parent][child];
  }

  /**
   * @dev Get total vault balance for a token
   * @param token Address of the token
   * @return Total balance in vault
   */
  function getTotalVaultBalance(address token) external view returns (uint256) {
    return totalVaultBalances[token];
  }
}
