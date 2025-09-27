// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';
import '../src/bank/KidsViewerPiggyBank.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract KidsViewerPiggyBankTest is Test {
  KidsViewerPiggyBank public piggyBank;
  address public owner = address(0x1);
  address public parent1 = address(0x2);
  address public parent2 = address(0x3);
  uint64 public person1 = 1;
  uint64 public person2 = 2;
  address public token1 = address(0x6);
  address public token2 = address(0x7);
  address public aaveProduct1 = address(0x8);

  function setUp() public {
    vm.prank(owner);
    piggyBank = new KidsViewerPiggyBank();
  }

  function testInitialState() public {
    assertEq(piggyBank.owner(), owner);
    assertFalse(piggyBank.paused());
    assertEq(piggyBank.nextRequestId(), 1);
  }

  function testReceiveReward() public {
    uint256 rewardAmount = 1000 * 10 ** 6;

    vm.prank(parent1);
    piggyBank.setParentApproval(person1, true);

    vm.prank(parent1);
    piggyBank.receiveReward(person1, token1, rewardAmount);

    assertEq(piggyBank.personBalances(person1, token1), rewardAmount);
    assertEq(piggyBank.personEarnings(person1, token1), rewardAmount);
  }

  function testReceiveRewardRevertsWhenPaused() public {
    uint256 rewardAmount = 1000 * 10 ** 6;

    vm.prank(owner);
    piggyBank.pause();

    vm.prank(parent1);
    piggyBank.setParentApproval(person1, true);

    vm.prank(parent1);
    vm.expectRevert('KidsViewerPiggyBank: Paused');
    piggyBank.receiveReward(person1, token1, rewardAmount);
  }

  function testReceiveRewardRevertsWhenAmountZero() public {
    vm.prank(parent1);
    piggyBank.setParentApproval(person1, true);

    vm.prank(parent1);
    vm.expectRevert('KidsViewerPiggyBank: Amount > 0');
    piggyBank.receiveReward(person1, token1, 0);
  }

  function testReceiveRewardRevertsWhenNotParent() public {
    uint256 rewardAmount = 1000 * 10 ** 6;

    vm.prank(parent1);
    vm.expectRevert('KidsViewerPiggyBank: Not parent');
    piggyBank.receiveReward(person1, token1, rewardAmount);
  }

  function testRequestWithdrawal() public {
    uint256 amount = 500 * 10 ** 6;
    string memory reason = 'Need money for school supplies';

    // First give child some balance
    vm.prank(parent1);
    piggyBank.setParentApproval(person1, true);

    vm.prank(parent1);
    piggyBank.receiveReward(person1, token1, 1000 * 10 ** 6);

    // Then request withdrawal
    vm.prank(parent1);
    piggyBank.requestWithdrawal(person1, token1, amount, reason);

    assertEq(piggyBank.personRequestIds(person1), 1);

    KidsViewerPiggyBank.WithdrawalRequest memory request = piggyBank.getWithdrawalRequest(1);
    assertEq(request.personId, person1);
    assertEq(request.token, token1);
    assertEq(request.amount, amount);
    assertEq(request.reason, reason);
    assertFalse(request.approved);
    assertFalse(request.executed);
  }

  function testRequestWithdrawalRevertsWhenPaused() public {
    uint256 amount = 500 * 10 ** 6;
    string memory reason = 'Need money for school supplies';

    vm.prank(owner);
    piggyBank.pause();

    vm.prank(parent1);
    vm.expectRevert('KidsViewerPiggyBank: Paused');
    piggyBank.requestWithdrawal(person1, token1, amount, reason);
  }

  function testRequestWithdrawalRevertsWhenAmountZero() public {
    string memory reason = 'Need money for school supplies';

    vm.prank(parent1);
    vm.expectRevert('KidsViewerPiggyBank: Amount > 0');
    piggyBank.requestWithdrawal(person1, token1, 0, reason);
  }

  function testRequestWithdrawalRevertsWhenInsufficientBalance() public {
    uint256 amount = 500 * 10 ** 6;
    string memory reason = 'Need money for school supplies';

    vm.prank(parent1);
    piggyBank.setParentApproval(person1, true);

    vm.prank(parent1);
    vm.expectRevert('KidsViewerPiggyBank: Insufficient');
    piggyBank.requestWithdrawal(person1, token1, amount, reason);
  }

  function testApproveWithdrawal() public {
    uint256 amount = 500 * 10 ** 6;
    string memory reason = 'Need money for school supplies';

    // Setup: parent approval and child balance
    vm.prank(parent1);
    piggyBank.setParentApproval(person1, true);

    vm.prank(parent1);
    piggyBank.receiveReward(person1, token1, 1000 * 10 ** 6);

    // Request withdrawal
    vm.prank(parent1);
    piggyBank.requestWithdrawal(person1, token1, amount, reason);

    // Approve withdrawal
    vm.prank(owner);
    piggyBank.approveWithdrawal(1);

    KidsViewerPiggyBank.WithdrawalRequest memory request = piggyBank.getWithdrawalRequest(1);
    assertTrue(request.approved);
    assertEq(piggyBank.personBalances(person1, token1), 1000 * 10 ** 6 - amount);
  }

  function testApproveWithdrawalRevertsWhenNotOwner() public {
    uint256 amount = 500 * 10 ** 6;
    string memory reason = 'Need money for school supplies';

    // Setup
    vm.prank(parent1);
    piggyBank.setParentApproval(person1, true);

    vm.prank(parent1);
    piggyBank.receiveReward(person1, token1, 1000 * 10 ** 6);

    vm.prank(parent1);
    piggyBank.requestWithdrawal(person1, token1, amount, reason);

    vm.prank(parent1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, parent1));
    piggyBank.approveWithdrawal(1);
  }

  function testApproveWithdrawalRevertsWhenPaused() public {
    uint256 amount = 500 * 10 ** 6;
    string memory reason = 'Need money for school supplies';

    // Setup
    vm.prank(parent1);
    piggyBank.setParentApproval(person1, true);

    vm.prank(parent1);
    piggyBank.receiveReward(person1, token1, 1000 * 10 ** 6);

    vm.prank(parent1);
    piggyBank.requestWithdrawal(person1, token1, amount, reason);

    vm.prank(owner);
    piggyBank.pause();

    vm.prank(owner);
    vm.expectRevert('KidsViewerPiggyBank: Paused');
    piggyBank.approveWithdrawal(1);
  }

  function testRejectWithdrawal() public {
    uint256 amount = 500 * 10 ** 6;
    string memory reason = 'Need money for school supplies';
    string memory rejectionReason = 'Not a valid reason';

    // Setup
    vm.prank(parent1);
    piggyBank.setParentApproval(person1, true);

    vm.prank(parent1);
    piggyBank.receiveReward(person1, token1, 1000 * 10 ** 6);

    vm.prank(parent1);
    piggyBank.requestWithdrawal(person1, token1, amount, reason);

    // Reject withdrawal
    vm.prank(owner);
    piggyBank.rejectWithdrawal(1, rejectionReason);

    KidsViewerPiggyBank.WithdrawalRequest memory request = piggyBank.getWithdrawalRequest(1);
    assertFalse(request.approved);
    assertTrue(request.executed);
    assertEq(request.reason, rejectionReason);
  }

  function testInvestInAave() public {
    uint256 amount = 500 * 10 ** 6;

    // Setup: give child some balance
    vm.prank(parent1);
    piggyBank.setParentApproval(person1, true);

    vm.prank(parent1);
    piggyBank.receiveReward(person1, token1, 1000 * 10 ** 6);

    // Invest
    vm.prank(parent1);
    piggyBank.investInAave(person1, token1, amount, aaveProduct1);

    assertEq(piggyBank.personBalances(person1, token1), 1000 * 10 ** 6 - amount);
  }

  function testInvestInAaveRevertsWhenPaused() public {
    uint256 amount = 500 * 10 ** 6;

    vm.prank(owner);
    piggyBank.pause();

    vm.prank(parent1);
    vm.expectRevert('KidsViewerPiggyBank: Paused');
    piggyBank.investInAave(person1, token1, amount, aaveProduct1);
  }

  function testInvestInAaveRevertsWhenAmountZero() public {
    vm.prank(parent1);
    vm.expectRevert('KidsViewerPiggyBank: Amount > 0');
    piggyBank.investInAave(person1, token1, 0, aaveProduct1);
  }

  function testInvestInAaveRevertsWhenInsufficientBalance() public {
    uint256 amount = 500 * 10 ** 6;

    vm.prank(parent1);
    piggyBank.setParentApproval(person1, true);

    vm.prank(parent1);
    vm.expectRevert('KidsViewerPiggyBank: Insufficient');
    piggyBank.investInAave(person1, token1, amount, aaveProduct1);
  }

  function testRecoverAllInvestments() public {
    uint256 amount = 500 * 10 ** 6;

    // Setup: give child some balance
    vm.prank(parent1);
    piggyBank.setParentApproval(person1, true);

    vm.prank(parent1);
    piggyBank.receiveReward(person1, token1, amount);

    // Recover investments
    vm.prank(parent1);
    piggyBank.recoverAllInvestments(person1, token1);

    assertEq(piggyBank.personBalances(person1, token1), 0);
  }

  function testRecoverAllInvestmentsRevertsWhenNotParent() public {
    vm.prank(parent2);
    vm.expectRevert('KidsViewerPiggyBank: Not parent');
    piggyBank.recoverAllInvestments(person1, token1);
  }

  function testSetParentApproval() public {
    vm.prank(parent1);
    piggyBank.setParentApproval(person1, true);

    assertTrue(piggyBank.parentApprovals(parent1, person1));
  }

  function testSetInvestmentConfig() public {
    bool enabled = true;
    uint256 maxAmount = 10000 * 10 ** 6;

    vm.prank(parent1);
    piggyBank.setParentApproval(person1, true);

    vm.prank(parent1);
    piggyBank.setInvestmentConfig(person1, enabled, maxAmount);

    (bool isEnabled, uint256 maxInvestmentAmount, uint256 totalInvested) = piggyBank.getInvestmentConfig(person1);
    assertTrue(isEnabled);
    assertEq(maxInvestmentAmount, maxAmount);
    assertEq(totalInvested, 0);
  }

  function testSetInvestmentConfigRevertsWhenNotParent() public {
    bool enabled = true;
    uint256 maxAmount = 10000 * 10 ** 6;

    vm.prank(parent1);
    vm.expectRevert('KidsViewerPiggyBank: Not parent');
    piggyBank.setInvestmentConfig(person1, enabled, maxAmount);
  }

  function testSetAaveProductApproval() public {
    bool approved = true;

    vm.prank(parent1);
    piggyBank.setParentApproval(person1, true);

    vm.prank(parent1);
    piggyBank.setAaveProductApproval(person1, aaveProduct1, approved);

    assertTrue(piggyBank.aaveProductApprovals(person1, aaveProduct1));
  }

  function testSetAaveProductApprovalRevertsWhenNotParent() public {
    bool approved = true;

    vm.prank(parent1);
    vm.expectRevert('KidsViewerPiggyBank: Not parent');
    piggyBank.setAaveProductApproval(person1, aaveProduct1, approved);
  }

  function testSetChildActive() public {
    vm.prank(owner);
    piggyBank.setPersonActive(person1, true);

    assertTrue(piggyBank.personActive(person1));
  }

  function testSetChildActiveRevertsWhenNotOwner() public {
    vm.prank(parent1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, parent1));
    piggyBank.setPersonActive(person1, true);
  }

  function testPause() public {
    vm.prank(owner);
    piggyBank.pause();

    assertTrue(piggyBank.paused());
  }

  function testUnpause() public {
    vm.prank(owner);
    piggyBank.pause();

    vm.prank(owner);
    piggyBank.unpause();

    assertFalse(piggyBank.paused());
  }

  function testGetChildBalance() public {
    uint256 amount = 1000 * 10 ** 6;

    vm.prank(parent1);
    piggyBank.setParentApproval(person1, true);

    vm.prank(parent1);
    piggyBank.receiveReward(person1, token1, amount);

    assertEq(piggyBank.getPersonBalance(person1, token1), amount);
  }

  function testGetChildEarnings() public {
    uint256 amount = 1000 * 10 ** 6;

    vm.prank(parent1);
    piggyBank.setParentApproval(person1, true);

    vm.prank(parent1);
    piggyBank.receiveReward(person1, token1, amount);

    (uint256 balance, uint256 earnings) = piggyBank.getPersonEarnings(person1, token1);
    assertEq(balance, amount);
    assertEq(earnings, amount);
  }

  function testGetWithdrawalRequest() public {
    uint256 amount = 500 * 10 ** 6;
    string memory reason = 'Need money for school supplies';

    // Setup
    vm.prank(parent1);
    piggyBank.setParentApproval(person1, true);

    vm.prank(parent1);
    piggyBank.receiveReward(person1, token1, 1000 * 10 ** 6);

    vm.prank(parent1);
    piggyBank.requestWithdrawal(person1, token1, amount, reason);

    KidsViewerPiggyBank.WithdrawalRequest memory request = piggyBank.getWithdrawalRequest(1);
    assertEq(request.personId, person1);
    assertEq(request.token, token1);
    assertEq(request.amount, amount);
    assertEq(request.reason, reason);
  }

  function testGetChildWithdrawalRequests() public {
    uint256 amount = 500 * 10 ** 6;
    string memory reason = 'Need money for school supplies';

    // Setup
    vm.prank(parent1);
    piggyBank.setParentApproval(person1, true);

    vm.prank(parent1);
    piggyBank.receiveReward(person1, token1, 1000 * 10 ** 6);

    vm.prank(parent1);
    piggyBank.requestWithdrawal(person1, token1, amount, reason);

    assertEq(piggyBank.getPersonWithdrawalRequests(person1), 1);
  }

  function testIsAaveProductApproved() public {
    vm.prank(parent1);
    piggyBank.setParentApproval(person1, true);

    vm.prank(parent1);
    piggyBank.setAaveProductApproval(person1, aaveProduct1, true);

    assertTrue(piggyBank.isAaveProductApproved(person1, aaveProduct1));
    assertFalse(piggyBank.isAaveProductApproved(person1, address(uint160(aaveProduct1) + 1)));
  }

  function testIsParentApproved() public {
    vm.prank(parent1);
    piggyBank.setParentApproval(person1, true);

    assertTrue(piggyBank.isParentApproved(parent1, person1));
    assertFalse(piggyBank.isParentApproved(parent2, person1));
  }

  function testIsChildActive() public {
    vm.prank(owner);
    piggyBank.setPersonActive(person1, true);

    assertTrue(piggyBank.isPersonActive(person1));
    assertFalse(piggyBank.isPersonActive(person2));
  }
}
