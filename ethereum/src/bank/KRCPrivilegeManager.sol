// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/**
 * @title KRC Privilege Manager
 * @dev Manages user privileges and governance for KRC token holders
 * @notice This contract handles privilege access, governance proposals, and voting
 */
contract KRCPrivilegeManager is Ownable {
  // Events
  event PrivilegeAccessGranted(address indexed user, string feature, uint256 timestamp);
  event PrivilegeAccessRevoked(address indexed user, string feature, uint256 timestamp);
  event PrivilegeLevelUpdated(address indexed user, uint8 level, uint256 timestamp);
  event ProposalCreated(uint256 indexed proposalId, address indexed proposer, string title, string description, string proposalType, uint256 startTime, uint256 endTime);
  event VoteCast(address indexed user, uint256 indexed proposalId, bool support, uint256 votes, uint256 timestamp);
  event ProposalExecuted(uint256 indexed proposalId, string proposalType, uint256 timestamp);
  event KRCContractSet(address indexed krcContract, uint256 timestamp);

  // Structs
  struct Proposal {
    uint256 id;
    string title;
    string description;
    string proposalType; // e.g: 'feature' or 'governance'
    address proposer;
    uint256 startTime;
    uint256 endTime;
    uint256 forVotes;
    uint256 againstVotes;
    bool executed;
    uint256 createdAt;
  }

  // State variables
  address public krcContract;
  mapping(address => mapping(string => bool)) public userPrivileges; // user => feature => has_access
  mapping(address => uint8) public userPrivilegeLevels;
  mapping(uint256 => Proposal) public proposals;
  mapping(address => mapping(uint256 => bool)) public hasVoted; // user => proposalId => hasVoted
  uint256 public nextProposalId = 1;

  // Constants
  uint256 public constant MIN_VOTING_BALANCE = 1000 * 10**18; // 1K KRC
  uint256 public constant MIN_PROPOSAL_DURATION = 1 days;
  uint256 public constant MAX_PROPOSAL_DURATION = 7 days;

  // Modifiers
  modifier onlyKrcHolder() {
    require(krcContract != address(0), 'KRC contract not set');
    IERC20 krc = IERC20(krcContract);
    require(krc.balanceOf(msg.sender) >= MIN_VOTING_BALANCE, 'Insufficient KRC balance');
    _;
  }

  modifier validProposalDuration(uint256 duration) {
    require(duration >= MIN_PROPOSAL_DURATION, 'Duration too short');
    require(duration <= MAX_PROPOSAL_DURATION, 'Duration too long');
    _;
  }

  constructor() Ownable(msg.sender) {}

  /**
   * @dev Grant privilege access to user
   * @param user Address of the user
   * @param feature Feature to grant access to
   */
  function grantPrivilegeAccess(address user, string calldata feature) external onlyOwner {
    userPrivileges[user][feature] = true;
    emit PrivilegeAccessGranted(user, feature, block.timestamp);
  }

  /**
   * @dev Revoke privilege access from user
   * @param user Address of the user
   * @param feature Feature to revoke access from
   */
  function revokePrivilegeAccess(address user, string calldata feature) external onlyOwner {
    userPrivileges[user][feature] = false;
    emit PrivilegeAccessRevoked(user, feature, block.timestamp);
  }

  /**
   * @dev Check if user has privilege access
   * @param user Address of the user
   * @param feature Feature to check
   * @return Whether user has access
   */
  function hasPrivilegeAccess(address user, string calldata feature) external view returns (bool) {
    return userPrivileges[user][feature];
  }

  /**
   * @dev Get user privileges (simplified - returns empty array)
   * @param user Address of the user
   * @return Array of privilege features
   */
  function getUserPrivileges(address user) external pure returns (string[] memory) {
    // In a real implementation, you'd need to iterate through all possible features
    // For now, return empty array as this would require more complex storage patterns
    string[] memory privileges = new string[](0);
    return privileges;
  }

  /**
   * @dev Create a governance proposal
   * @param title Proposal title
   * @param description Proposal description
   * @param proposalType Type of proposal ('feature' or 'governance')
   * @param duration Voting duration in seconds
   */
  function createProposal(
    string calldata title,
    string calldata description,
    string calldata proposalType,
    uint256 duration
  ) external onlyKrcHolder validProposalDuration(duration) {
    uint256 proposalId = nextProposalId++;
    uint256 startTime = block.timestamp + 1 hours; // 1 hour delay
    uint256 endTime = startTime + duration;

    proposals[proposalId] = Proposal({
      id: proposalId,
      title: title,
      description: description,
      proposalType: proposalType,
      proposer: msg.sender,
      startTime: startTime,
      endTime: endTime,
      forVotes: 0,
      againstVotes: 0,
      executed: false,
      createdAt: block.timestamp
    });

    emit ProposalCreated(proposalId, msg.sender, title, description, proposalType, startTime, endTime);
  }

  /**
   * @dev Vote on a proposal
   * @param proposalId ID of the proposal
   * @param support Whether to support the proposal
   */
  function voteOnProposal(uint256 proposalId, bool support) external onlyKrcHolder {
    Proposal storage proposal = proposals[proposalId];
    require(proposal.id != 0, 'Proposal not found');
    require(block.timestamp >= proposal.startTime, 'Voting not started');
    require(block.timestamp <= proposal.endTime, 'Voting period ended');
    require(!hasVoted[msg.sender][proposalId], 'Already voted');

    // Get KRC balance for voting power
    IERC20 krc = IERC20(krcContract);
    uint256 balance = krc.balanceOf(msg.sender);

    hasVoted[msg.sender][proposalId] = true;

    if (support) {
      proposal.forVotes += balance;
    } else {
      proposal.againstVotes += balance;
    }

    emit VoteCast(msg.sender, proposalId, support, balance, block.timestamp);
  }

  /**
   * @dev Execute a proposal (only if it passed)
   * @param proposalId ID of the proposal
   */
  function executeProposal(uint256 proposalId) external onlyOwner {
    Proposal storage proposal = proposals[proposalId];
    require(proposal.id != 0, 'Proposal not found');
    require(block.timestamp > proposal.endTime, 'Voting period not ended');
    require(!proposal.executed, 'Proposal already executed');
    require(proposal.forVotes >= proposal.againstVotes, 'Proposal did not pass');

    proposal.executed = true;

    // Handle different proposal types
    if (keccak256(bytes(proposal.proposalType)) == keccak256(bytes('feature'))) {
      // Grant privilege access to all KRC holders for the approved feature
      // This is a simplified implementation - in practice, you'd need to track all KRC holders
    }

    emit ProposalExecuted(proposalId, proposal.proposalType, block.timestamp);
  }

  /**
   * @dev Get proposal details
   * @param proposalId ID of the proposal
   * @return proposal Proposal details
   */
  function getProposal(uint256 proposalId) external view returns (Proposal memory) {
    require(proposals[proposalId].id != 0, 'Proposal not found');
    return proposals[proposalId];
  }

  /**
   * @dev Check if user has voted on proposal
   * @param user Address of the user
   * @param proposalId ID of the proposal
   * @return Whether user has voted
   */
  function getUserVotes(address user, uint256 proposalId) external view returns (bool) {
    return hasVoted[user][proposalId];
  }

  /**
   * @dev Update user privilege level
   * @param user Address of the user
   * @param level Privilege level
   */
  function updateUserPrivilegeLevel(address user, uint8 level) external onlyOwner {
    userPrivilegeLevels[user] = level;
    emit PrivilegeLevelUpdated(user, level, block.timestamp);
  }

  /**
   * @dev Get user privilege level
   * @param user Address of the user
   * @return Privilege level
   */
  function getUserPrivilegeLevel(address user) external view returns (uint8) {
    return userPrivilegeLevels[user];
  }

  /**
   * @dev Set KRC contract address
   * @param _krcContract Address of the KRC contract
   */
  function setKrcContract(address _krcContract) external onlyOwner {
    krcContract = _krcContract;
    emit KRCContractSet(_krcContract, block.timestamp);
  }

  /**
   * @dev Get KRC contract address
   * @return Address of the KRC contract
   */
  function getKrcContract() external view returns (address) {
    return krcContract;
  }
}
