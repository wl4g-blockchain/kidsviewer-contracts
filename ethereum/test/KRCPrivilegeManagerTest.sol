// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';
import '../src/bank/KRCPrivilegeManager.sol';
import '../src/bank/KRC.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract KRCPrivilegeManagerTest is Test {
  KRCPrivilegeManager public privilegeManager;
  KRC public krc;
  address public owner = address(0x1);
  address public user1 = address(0x2);
  address public user2 = address(0x3);

  function setUp() public {
    vm.prank(owner);
    krc = new KRC();

    vm.prank(owner);
    privilegeManager = new KRCPrivilegeManager();

    vm.prank(owner);
    privilegeManager.setKrcContract(address(krc));
  }

  function testInitialState() public {
    assertEq(privilegeManager.owner(), owner);
    assertEq(privilegeManager.getKrcContract(), address(krc));
    assertEq(privilegeManager.nextProposalId(), 1);
  }

  function testGrantPrivilegeAccess() public {
    string memory feature = 'premium_features';

    vm.prank(owner);
    privilegeManager.grantPrivilegeAccess(user1, feature);

    assertTrue(privilegeManager.hasPrivilegeAccess(user1, feature));
  }

  function testGrantPrivilegeAccessRevertsWhenNotOwner() public {
    string memory feature = 'premium_features';

    vm.prank(user1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
    privilegeManager.grantPrivilegeAccess(user1, feature);
  }

  function testRevokePrivilegeAccess() public {
    string memory feature = 'premium_features';

    // First grant access
    vm.prank(owner);
    privilegeManager.grantPrivilegeAccess(user1, feature);

    // Then revoke it
    vm.prank(owner);
    privilegeManager.revokePrivilegeAccess(user1, feature);

    assertFalse(privilegeManager.hasPrivilegeAccess(user1, feature));
  }

  function testRevokePrivilegeAccessRevertsWhenNotOwner() public {
    string memory feature = 'premium_features';

    vm.prank(user1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
    privilegeManager.revokePrivilegeAccess(user1, feature);
  }

  function testHasPrivilegeAccess() public {
    string memory feature = 'premium_features';

    assertFalse(privilegeManager.hasPrivilegeAccess(user1, feature));

    vm.prank(owner);
    privilegeManager.grantPrivilegeAccess(user1, feature);

    assertTrue(privilegeManager.hasPrivilegeAccess(user1, feature));
  }

  function testGetUserPrivileges() public {
    string[] memory privileges = privilegeManager.getUserPrivileges(user1);
    assertEq(privileges.length, 0);
  }

  function testCreateProposal() public {
    string memory title = 'Test Proposal';
    string memory description = 'This is a test proposal';
    string memory proposalType = 'feature';
    uint256 duration = 2 days;

    // Give user1 some KRC tokens
    vm.prank(owner);
    krc.mint(user1, 2000 * 10 ** 18);

    vm.prank(user1);
    privilegeManager.createProposal(title, description, proposalType, duration);

    KRCPrivilegeManager.Proposal memory proposal = privilegeManager.getProposal(1);
    assertEq(proposal.id, 1);
    assertEq(proposal.title, title);
    assertEq(proposal.description, description);
    assertEq(proposal.proposalType, proposalType);
    assertEq(proposal.proposer, user1);
    assertFalse(proposal.executed);
  }

  function testCreateProposalRevertsWhenInsufficientBalance() public {
    string memory title = 'Test Proposal';
    string memory description = 'This is a test proposal';
    string memory proposalType = 'feature';
    uint256 duration = 2 days;

    vm.prank(user1);
    vm.expectRevert('Insufficient KRC balance');
    privilegeManager.createProposal(title, description, proposalType, duration);
  }

  function testCreateProposalRevertsWhenDurationTooShort() public {
    string memory title = 'Test Proposal';
    string memory description = 'This is a test proposal';
    string memory proposalType = 'feature';
    uint256 duration = 12 hours; // Too short

    // Give user1 some KRC tokens
    vm.prank(owner);
    krc.mint(user1, 2000 * 10 ** 18);

    vm.prank(user1);
    vm.expectRevert('Duration too short');
    privilegeManager.createProposal(title, description, proposalType, duration);
  }

  function testCreateProposalRevertsWhenDurationTooLong() public {
    string memory title = 'Test Proposal';
    string memory description = 'This is a test proposal';
    string memory proposalType = 'feature';
    uint256 duration = 8 days; // Too long

    // Give user1 some KRC tokens
    vm.prank(owner);
    krc.mint(user1, 2000 * 10 ** 18);

    vm.prank(user1);
    vm.expectRevert('Duration too long');
    privilegeManager.createProposal(title, description, proposalType, duration);
  }

  function testVoteOnProposal() public {
    string memory title = 'Test Proposal';
    string memory description = 'This is a test proposal';
    string memory proposalType = 'feature';
    uint256 duration = 2 days;

    // Give users some KRC tokens
    vm.prank(owner);
    krc.mint(user1, 2000 * 10 ** 18);
    vm.prank(owner);
    krc.mint(user2, 1500 * 10 ** 18);

    // Create proposal
    vm.prank(user1);
    privilegeManager.createProposal(title, description, proposalType, duration);

    // Fast forward to voting period
    vm.warp(block.timestamp + 1 hours + 1);

    // Vote on proposal
    vm.prank(user1);
    privilegeManager.voteOnProposal(1, true);

    vm.prank(user2);
    privilegeManager.voteOnProposal(1, false);

    KRCPrivilegeManager.Proposal memory proposal = privilegeManager.getProposal(1);
    assertEq(proposal.forVotes, 2000 * 10 ** 18);
    assertEq(proposal.againstVotes, 1500 * 10 ** 18);
    assertTrue(privilegeManager.getUserVotes(user1, 1));
    assertTrue(privilegeManager.getUserVotes(user2, 1));
  }

  function testVoteOnProposalRevertsWhenInsufficientBalance() public {
    string memory title = 'Test Proposal';
    string memory description = 'This is a test proposal';
    string memory proposalType = 'feature';
    uint256 duration = 2 days;

    // Give user1 some KRC tokens
    vm.prank(owner);
    krc.mint(user1, 2000 * 10 ** 18);

    // Create proposal
    vm.prank(user1);
    privilegeManager.createProposal(title, description, proposalType, duration);

    // Fast forward to voting period
    vm.warp(block.timestamp + 1 hours + 1);

    // user2 doesn't have enough KRC
    vm.prank(user2);
    vm.expectRevert('Insufficient KRC balance');
    privilegeManager.voteOnProposal(1, true);
  }

  function testVoteOnProposalRevertsWhenVotingNotStarted() public {
    string memory title = 'Test Proposal';
    string memory description = 'This is a test proposal';
    string memory proposalType = 'feature';
    uint256 duration = 2 days;

    // Give user1 some KRC tokens
    vm.prank(owner);
    krc.mint(user1, 2000 * 10 ** 18);

    // Create proposal
    vm.prank(user1);
    privilegeManager.createProposal(title, description, proposalType, duration);

    // Try to vote immediately (before 1 hour delay)
    vm.prank(user1);
    vm.expectRevert('Voting not started');
    privilegeManager.voteOnProposal(1, true);
  }

  function testVoteOnProposalRevertsWhenVotingEnded() public {
    string memory title = 'Test Proposal';
    string memory description = 'This is a test proposal';
    string memory proposalType = 'feature';
    uint256 duration = 2 days;

    // Give user1 some KRC tokens
    vm.prank(owner);
    krc.mint(user1, 2000 * 10 ** 18);

    // Create proposal
    vm.prank(user1);
    privilegeManager.createProposal(title, description, proposalType, duration);

    // Fast forward past voting period
    vm.warp(block.timestamp + 1 hours + duration + 1);

    vm.prank(user1);
    vm.expectRevert('Voting period ended');
    privilegeManager.voteOnProposal(1, true);
  }

  function testVoteOnProposalRevertsWhenAlreadyVoted() public {
    string memory title = 'Test Proposal';
    string memory description = 'This is a test proposal';
    string memory proposalType = 'feature';
    uint256 duration = 2 days;

    // Give user1 some KRC tokens
    vm.prank(owner);
    krc.mint(user1, 2000 * 10 ** 18);

    // Create proposal
    vm.prank(user1);
    privilegeManager.createProposal(title, description, proposalType, duration);

    // Fast forward to voting period
    vm.warp(block.timestamp + 1 hours + 1);

    // Vote once
    vm.prank(user1);
    privilegeManager.voteOnProposal(1, true);

    // Try to vote again
    vm.prank(user1);
    vm.expectRevert('Already voted');
    privilegeManager.voteOnProposal(1, true);
  }

  function testExecuteProposal() public {
    string memory title = 'Test Proposal';
    string memory description = 'This is a test proposal';
    string memory proposalType = 'feature';
    uint256 duration = 2 days;

    // Give user1 some KRC tokens
    vm.prank(owner);
    krc.mint(user1, 2000 * 10 ** 18);

    // Create proposal
    vm.prank(user1);
    privilegeManager.createProposal(title, description, proposalType, duration);

    // Fast forward to voting period
    vm.warp(block.timestamp + 1 hours + 1);

    // Vote for the proposal
    vm.prank(user1);
    privilegeManager.voteOnProposal(1, true);

    // Fast forward past voting period
    vm.warp(block.timestamp + duration);

    // Execute proposal
    vm.prank(owner);
    privilegeManager.executeProposal(1);

    KRCPrivilegeManager.Proposal memory proposal = privilegeManager.getProposal(1);
    assertTrue(proposal.executed);
  }

  function testExecuteProposalRevertsWhenNotOwner() public {
    string memory title = 'Test Proposal';
    string memory description = 'This is a test proposal';
    string memory proposalType = 'feature';
    uint256 duration = 2 days;

    // Give user1 some KRC tokens
    vm.prank(owner);
    krc.mint(user1, 2000 * 10 ** 18);

    // Create proposal
    vm.prank(user1);
    privilegeManager.createProposal(title, description, proposalType, duration);

    // Fast forward past voting period
    vm.warp(block.timestamp + 1 hours + duration + 1);

    vm.prank(user1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
    privilegeManager.executeProposal(1);
  }

  function testExecuteProposalRevertsWhenVotingNotEnded() public {
    string memory title = 'Test Proposal';
    string memory description = 'This is a test proposal';
    string memory proposalType = 'feature';
    uint256 duration = 2 days;

    // Give user1 some KRC tokens
    vm.prank(owner);
    krc.mint(user1, 2000 * 10 ** 18);

    // Create proposal
    vm.prank(user1);
    privilegeManager.createProposal(title, description, proposalType, duration);

    // Fast forward to voting period but not past it
    vm.warp(block.timestamp + 1 hours + 1);

    vm.prank(owner);
    vm.expectRevert('Voting period not ended');
    privilegeManager.executeProposal(1);
  }

  function testExecuteProposalRevertsWhenProposalDidNotPass() public {
    string memory title = 'Test Proposal';
    string memory description = 'This is a test proposal';
    string memory proposalType = 'feature';
    uint256 duration = 2 days;

    // Give users some KRC tokens
    vm.prank(owner);
    krc.mint(user1, 1000 * 10 ** 18);
    vm.prank(owner);
    krc.mint(user2, 2000 * 10 ** 18);

    // Create proposal
    vm.prank(user1);
    privilegeManager.createProposal(title, description, proposalType, duration);

    // Fast forward to voting period
    vm.warp(block.timestamp + 1 hours + 1);

    // Vote against the proposal (more votes against)
    vm.prank(user1);
    privilegeManager.voteOnProposal(1, true);

    vm.prank(user2);
    privilegeManager.voteOnProposal(1, false);

    // Fast forward past voting period
    vm.warp(block.timestamp + duration);

    vm.prank(owner);
    vm.expectRevert('Proposal did not pass');
    privilegeManager.executeProposal(1);
  }

  function testUpdateUserPrivilegeLevel() public {
    uint8 level = 5;

    vm.prank(owner);
    privilegeManager.updateUserPrivilegeLevel(user1, level);

    assertEq(privilegeManager.getUserPrivilegeLevel(user1), level);
  }

  function testUpdateUserPrivilegeLevelRevertsWhenNotOwner() public {
    uint8 level = 5;

    vm.prank(user1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
    privilegeManager.updateUserPrivilegeLevel(user1, level);
  }

  function testSetKrcContract() public {
    address newKrc = address(0x999);

    vm.prank(owner);
    privilegeManager.setKrcContract(newKrc);

    assertEq(privilegeManager.getKrcContract(), newKrc);
  }

  function testSetKrcContractRevertsWhenNotOwner() public {
    address newKrc = address(0x999);

    vm.prank(user1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
    privilegeManager.setKrcContract(newKrc);
  }

  function testGetProposalRevertsWhenNotFound() public {
    vm.expectRevert('Proposal not found');
    privilegeManager.getProposal(999);
  }

  function testConstants() public {
    assertEq(privilegeManager.MIN_VOTING_BALANCE(), 1000 * 10 ** 18);
    assertEq(privilegeManager.MIN_PROPOSAL_DURATION(), 1 days);
    assertEq(privilegeManager.MAX_PROPOSAL_DURATION(), 7 days);
  }
}
