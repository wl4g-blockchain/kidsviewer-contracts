// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';
import '../src/bank/KidsViewerVault.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract KidsViewerVaultTest is Test {
  KidsViewerVault public vault;
  address public owner = address(0x1);
  address public parent1 = address(0x2);
  address public parent2 = address(0x3);
  address public child1 = address(0x4);
  address public child2 = address(0x5);
  address public token1 = address(0x6);
  address public token2 = address(0x7);

  uint256 public constant MAX_DAILY_LIMIT = 1000 * 10 ** 6;
  uint256 public constant MIN_DAILY_LIMIT = 1 * 10 ** 6;

  function setUp() public {
    vm.prank(owner);
    vault = new KidsViewerVault(MAX_DAILY_LIMIT, MIN_DAILY_LIMIT);
  }

  function testInitialState() public {
    assertEq(vault.owner(), owner);
    assertEq(vault.maxDailyLimit(), MAX_DAILY_LIMIT);
    assertEq(vault.minDailyLimit(), MIN_DAILY_LIMIT);
    assertFalse(vault.paused());
  }

  function testAddSupportedToken() public {
    vm.prank(owner);
    vault.addSupportedToken(token1);

    assertTrue(vault.supportedTokens(token1));
  }

  function testAddSupportedTokenRevertsWhenNotOwner() public {
    vm.prank(parent1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, parent1));
    vault.addSupportedToken(token1);
  }

  function testRemoveSupportedToken() public {
    vm.prank(owner);
    vault.addSupportedToken(token1);

    vm.prank(owner);
    vault.removeSupportedToken(token1);

    assertFalse(vault.supportedTokens(token1));
  }

  function testRegisterParent() public {
    vm.prank(owner);
    vault.registerParent(parent1);

    assertTrue(vault.parentActive(parent1));
  }

  function testRegisterParentRevertsWhenNotOwner() public {
    vm.prank(parent1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, parent1));
    vault.registerParent(parent1);
  }

  function testAuthorizeChild() public {
    // First register parent
    vm.prank(owner);
    vault.registerParent(parent1);

    // Then authorize child
    vm.prank(parent1);
    vault.authorizeChild(child1, true);

    assertTrue(vault.parentChildren(parent1, child1));
  }

  function testAuthorizeChildRevertsWhenNotParent() public {
    vm.prank(parent1);
    vm.expectRevert('KidsViewerVault: Only parent');
    vault.authorizeChild(child1, true);
  }

  function testSetDailyRewardLimit() public {
    uint256 dailyLimit = 100 * 10 ** 6;

    // Setup: register parent, authorize child, add token
    vm.startPrank(owner);
    vault.registerParent(parent1);
    vault.addSupportedToken(token1);
    vm.stopPrank();

    vm.prank(parent1);
    vault.authorizeChild(child1, true);

    vm.prank(parent1);
    vault.setDailyRewardLimit(child1, token1, dailyLimit);

    assertEq(vault.childDailyLimit(child1), dailyLimit);
  }

  function testSetDailyRewardLimitRevertsWhenNotParent() public {
    uint256 dailyLimit = 100 * 10 ** 6;

    vm.prank(parent1);
    vm.expectRevert('KidsViewerVault: Only parent');
    vault.setDailyRewardLimit(child1, token1, dailyLimit);
  }

  function testSetDailyRewardLimitRevertsWhenNotAuthorizedChild() public {
    uint256 dailyLimit = 100 * 10 ** 6;

    vm.startPrank(owner);
    vault.registerParent(parent1);
    vault.addSupportedToken(token1);
    vm.stopPrank();

    vm.prank(parent1);
    vm.expectRevert('KidsViewerVault: Not authorized');
    vault.setDailyRewardLimit(child2, token1, dailyLimit);
  }

  function testSetDailyRewardLimitRevertsWhenTokenNotSupported() public {
    uint256 dailyLimit = 100 * 10 ** 6;

    vm.startPrank(owner);
    vault.registerParent(parent1);
    vm.stopPrank();

    vm.prank(parent1);
    vault.authorizeChild(child1, true);

    vm.prank(parent1);
    vm.expectRevert('KidsViewerVault: Not supported');
    vault.setDailyRewardLimit(child1, token1, dailyLimit);
  }

  function testSetDailyRewardLimitRevertsWhenLimitTooLow() public {
    uint256 dailyLimit = MIN_DAILY_LIMIT - 1;

    vm.startPrank(owner);
    vault.registerParent(parent1);
    vault.addSupportedToken(token1);
    vm.stopPrank();

    vm.prank(parent1);
    vault.authorizeChild(child1, true);

    vm.prank(parent1);
    vm.expectRevert('KidsViewerVault: Limit too low');
    vault.setDailyRewardLimit(child1, token1, dailyLimit);
  }

  function testSetDailyRewardLimitRevertsWhenLimitTooHigh() public {
    uint256 dailyLimit = MAX_DAILY_LIMIT + 1;

    vm.startPrank(owner);
    vault.registerParent(parent1);
    vault.addSupportedToken(token1);
    vm.stopPrank();

    vm.prank(parent1);
    vault.authorizeChild(child1, true);

    vm.prank(parent1);
    vm.expectRevert('KidsViewerVault: Limit too high');
    vault.setDailyRewardLimit(child1, token1, dailyLimit);
  }

  function testDeposit() public {
    uint256 depositAmount = 1000 * 10 ** 6;

    vm.startPrank(owner);
    vault.registerParent(parent1);
    vault.addSupportedToken(token1);
    vm.stopPrank();

    vm.prank(parent1);
    vault.deposit(token1, depositAmount);

    assertEq(vault.parentBalances(parent1, token1), depositAmount);
    assertEq(vault.totalVaultBalances(token1), depositAmount);
  }

  function testDepositRevertsWhenNotParent() public {
    uint256 depositAmount = 1000 * 10 ** 6;

    vm.startPrank(owner);
    vault.addSupportedToken(token1);
    vm.stopPrank();

    vm.prank(parent1);
    vm.expectRevert('KidsViewerVault: Only parent');
    vault.deposit(token1, depositAmount);
  }

  function testDepositRevertsWhenTokenNotSupported() public {
    uint256 depositAmount = 1000 * 10 ** 6;

    vm.startPrank(owner);
    vault.registerParent(parent1);
    vm.stopPrank();

    vm.prank(parent1);
    vm.expectRevert('KidsViewerVault: Not supported');
    vault.deposit(token1, depositAmount);
  }

  function testDepositRevertsWhenAmountZero() public {
    vm.startPrank(owner);
    vault.registerParent(parent1);
    vault.addSupportedToken(token1);
    vm.stopPrank();

    vm.prank(parent1);
    vm.expectRevert('KidsViewerVault: Amount > 0');
    vault.deposit(token1, 0);
  }

  function testWithdraw() public {
    uint256 depositAmount = 1000 * 10 ** 6;
    uint256 withdrawAmount = 500 * 10 ** 6;

    vm.startPrank(owner);
    vault.registerParent(parent1);
    vault.addSupportedToken(token1);
    vm.stopPrank();

    vm.prank(parent1);
    vault.deposit(token1, depositAmount);

    vm.prank(parent1);
    vault.withdraw(token1, withdrawAmount);

    assertEq(vault.parentBalances(parent1, token1), depositAmount - withdrawAmount);
    assertEq(vault.totalVaultBalances(token1), depositAmount - withdrawAmount);
  }

  function testWithdrawRevertsWhenInsufficientBalance() public {
    uint256 withdrawAmount = 500 * 10 ** 6;

    vm.startPrank(owner);
    vault.registerParent(parent1);
    vault.addSupportedToken(token1);
    vm.stopPrank();

    vm.prank(parent1);
    vm.expectRevert('KidsViewerVault: Insufficient');
    vault.withdraw(token1, withdrawAmount);
  }

  function testDistributeReward() public {
    uint256 depositAmount = 1000 * 10 ** 6;
    uint256 rewardAmount = 100 * 10 ** 6;
    uint256 dailyLimit = 200 * 10 ** 6;

    vm.startPrank(owner);
    vault.registerParent(parent1);
    vault.addSupportedToken(token1);
    vm.stopPrank();

    vm.prank(parent1);
    vault.authorizeChild(child1, true);

    vm.prank(parent1);
    vault.setDailyRewardLimit(child1, token1, dailyLimit);

    vm.prank(parent1);
    vault.setChildActive(child1, true);

    vm.prank(parent1);
    vault.deposit(token1, depositAmount);

    vm.prank(parent1);
    vault.distributeReward(child1, token1, rewardAmount);

    assertEq(vault.parentBalances(parent1, token1), depositAmount - rewardAmount);
    assertEq(vault.childDailyUsed(child1), rewardAmount);
  }

  function testDistributeRewardRevertsWhenChildNotActive() public {
    uint256 rewardAmount = 100 * 10 ** 6;

    vm.startPrank(owner);
    vault.registerParent(parent1);
    vault.addSupportedToken(token1);
    vm.stopPrank();

    vm.prank(parent1);
    vault.authorizeChild(child1, true);

    vm.prank(parent1);
    vm.expectRevert('KidsViewerVault: Not active');
    vault.distributeReward(child1, token1, rewardAmount);
  }

  function testDistributeRewardRevertsWhenDailyLimitExceeded() public {
    uint256 depositAmount = 1000 * 10 ** 6;
    uint256 rewardAmount = 100 * 10 ** 6;
    uint256 dailyLimit = 50 * 10 ** 6; // Lower than reward amount

    vm.startPrank(owner);
    vault.registerParent(parent1);
    vault.addSupportedToken(token1);
    vm.stopPrank();

    vm.prank(parent1);
    vault.authorizeChild(child1, true);

    vm.prank(parent1);
    vault.setDailyRewardLimit(child1, token1, dailyLimit);

    vm.prank(parent1);
    vault.setChildActive(child1, true);

    vm.prank(parent1);
    vault.deposit(token1, depositAmount);

    vm.prank(parent1);
    vm.expectRevert('KidsViewerVault: Limit exceeded');
    vault.distributeReward(child1, token1, rewardAmount);
  }

  function testSetChildActive() public {
    vm.startPrank(owner);
    vault.registerParent(parent1);
    vm.stopPrank();

    vm.prank(parent1);
    vault.authorizeChild(child1, true);

    vm.prank(parent1);
    vault.setChildActive(child1, true);

    assertTrue(vault.childActive(child1));
  }

  function testPause() public {
    vm.prank(owner);
    vault.pause();

    assertTrue(vault.paused());
  }

  function testUnpause() public {
    vm.prank(owner);
    vault.pause();

    vm.prank(owner);
    vault.unpause();

    assertFalse(vault.paused());
  }

  function testEmergencyWithdraw() public {
    uint256 amount = 1000 * 10 ** 6;

    vm.prank(owner);
    vault.emergencyWithdraw(token1, amount);

    // Should emit event (we can't test the actual transfer without a real token)
  }

  function testGetParentBalance() public {
    uint256 depositAmount = 1000 * 10 ** 6;

    vm.startPrank(owner);
    vault.registerParent(parent1);
    vault.addSupportedToken(token1);
    vm.stopPrank();

    vm.prank(parent1);
    vault.deposit(token1, depositAmount);

    assertEq(vault.getParentBalance(parent1, token1), depositAmount);
  }

  function testGetChildConfig() public {
    uint256 dailyLimit = 100 * 10 ** 6;

    vm.startPrank(owner);
    vault.registerParent(parent1);
    vault.addSupportedToken(token1);
    vm.stopPrank();

    vm.prank(parent1);
    vault.authorizeChild(child1, true);

    vm.prank(parent1);
    vault.setDailyRewardLimit(child1, token1, dailyLimit);

    vm.prank(parent1);
    vault.setChildActive(child1, true);

    (uint256 limit, uint256 used, uint64 lastReset, bool active) = vault.getChildConfig(child1);

    assertEq(limit, dailyLimit);
    assertEq(used, 0);
    assertEq(active, true);
  }

  function testIsParentAuthorized() public {
    vm.startPrank(owner);
    vault.registerParent(parent1);
    vm.stopPrank();

    vm.prank(parent1);
    vault.authorizeChild(child1, true);

    assertTrue(vault.isParentAuthorized(parent1, child1));
    assertFalse(vault.isParentAuthorized(parent1, child2));
  }

  function testGetTotalVaultBalance() public {
    uint256 depositAmount = 1000 * 10 ** 6;

    vm.startPrank(owner);
    vault.registerParent(parent1);
    vault.addSupportedToken(token1);
    vm.stopPrank();

    vm.prank(parent1);
    vault.deposit(token1, depositAmount);

    assertEq(vault.getTotalVaultBalance(token1), depositAmount);
  }
}
