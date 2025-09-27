// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import 'forge-std/Test.sol';
import '../src/bank/KRC.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract KRCTest is Test {
  KRC public krc;
  address public owner = address(0x1);
  address public user1 = address(0x2);
  address public user2 = address(0x3);

  function setUp() public {
    vm.prank(owner);
    krc = new KRC();
  }

  function testInitialState() public {
    assertEq(krc.name(), 'KRC');
    assertEq(krc.symbol(), 'KRC');
    assertEq(krc.decimals(), 18);
    assertEq(krc.totalSupply(), 10_000_000 * 10 ** 18);
    assertEq(krc.balanceOf(owner), 10_000_000 * 10 ** 18);
    assertEq(krc.owner(), owner);
    assertFalse(krc.paused());
  }

  function testMint() public {
    uint256 mintAmount = 1000 * 10 ** 18;

    vm.prank(owner);
    krc.mint(user1, mintAmount);

    assertEq(krc.balanceOf(user1), mintAmount);
    assertEq(krc.totalSupply(), 10_000_000 * 10 ** 18 + mintAmount);
  }

  function testMintRevertsWhenNotOwner() public {
    uint256 mintAmount = 1000 * 10 ** 18;

    vm.prank(user1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
    krc.mint(user2, mintAmount);
  }

  function testMintRevertsWhenExceedsMaxSupply() public {
    uint256 mintAmount = 100_000_000 * 10 ** 18; // Exceeds max supply

    vm.prank(owner);
    vm.expectRevert('KRC: Exceeds maximum supply');
    krc.mint(user1, mintAmount);
  }

  function testMintRevertsWhenAmountZero() public {
    vm.prank(owner);
    vm.expectRevert('KRC: Amount must be greater than 0');
    krc.mint(user1, 0);
  }

  function testBurn() public {
    uint256 burnAmount = 1000 * 10 ** 18;

    // First mint some tokens to user1
    vm.prank(owner);
    krc.mint(user1, burnAmount);

    // Then burn them
    vm.prank(user1);
    krc.burn(burnAmount);

    assertEq(krc.balanceOf(user1), 0);
    assertEq(krc.totalSupply(), 10_000_000 * 10 ** 18);
  }

  function testBurnRevertsWhenInsufficientBalance() public {
    uint256 burnAmount = 1000 * 10 ** 18;

    vm.prank(user1);
    vm.expectRevert('KRC: Insufficient balance');
    krc.burn(burnAmount);
  }

  function testBurnRevertsWhenAmountZero() public {
    vm.prank(user1);
    vm.expectRevert('KRC: Amount must be greater than 0');
    krc.burn(0);
  }

  function testPause() public {
    vm.prank(owner);
    krc.pause();

    assertTrue(krc.paused());
  }

  function testPauseRevertsWhenNotOwner() public {
    vm.prank(user1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
    krc.pause();
  }

  function testUnpause() public {
    vm.prank(owner);
    krc.pause();

    vm.prank(owner);
    krc.unpause();

    assertFalse(krc.paused());
  }

  function testUnpauseRevertsWhenNotOwner() public {
    vm.prank(owner);
    krc.pause();

    vm.prank(user1);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user1));
    krc.unpause();
  }

  function testTransferRevertsWhenPaused() public {
    uint256 transferAmount = 1000 * 10 ** 18;

    // Mint tokens to user1
    vm.prank(owner);
    krc.mint(user1, transferAmount);

    // Pause the contract
    vm.prank(owner);
    krc.pause();

    // Try to transfer
    vm.prank(user1);
    vm.expectRevert('KRC: Paused');
    krc.transfer(user2, transferAmount);
  }

  function testTransferWorksWhenNotPaused() public {
    uint256 transferAmount = 1000 * 10 ** 18;

    // Mint tokens to user1
    vm.prank(owner);
    krc.mint(user1, transferAmount);

    // Transfer should work
    vm.prank(user1);
    krc.transfer(user2, transferAmount);

    assertEq(krc.balanceOf(user2), transferAmount);
    assertEq(krc.balanceOf(user1), 0);
  }

  function testConstants() public {
    assertEq(krc.MAX_SUPPLY(), 100_000_000 * 10 ** 18);
    assertEq(krc.INITIAL_SUPPLY(), 10_000_000 * 10 ** 18);
  }
}
