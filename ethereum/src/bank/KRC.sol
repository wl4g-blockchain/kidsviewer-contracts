// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

/**
 * @title KRC (Knowledge Reward Coin)
 * @dev Platform utility token for KidsViewer platform
 * @notice This token provides basic ERC20 functionality with minting and burning capabilities
 */
contract KRC is ERC20, ERC20Burnable, Ownable {
  // State variables
  bool public paused;
  uint256 public constant MAX_SUPPLY = 100_000_000 * 10 ** 18; // 100 million KRC
  uint256 public constant INITIAL_SUPPLY = 10_000_000 * 10 ** 18; // 10 million KRC initial

  // Modifiers
  modifier validAmount(uint256 amount) {
    require(amount > 0, 'KRC: Amount must be greater than 0');
    _;
  }

  modifier whenNotPaused() {
    require(!paused, 'KRC: Paused');
    _;
  }

  constructor() ERC20('KRC', 'KRC') Ownable(msg.sender) {
    _mint(msg.sender, INITIAL_SUPPLY);
  }

  /**
   * @dev Mint new tokens (only owner)
   * @param to Address to mint to
   * @param amount Amount to mint
   */
  function mint(address to, uint256 amount) external onlyOwner validAmount(amount) {
    require(totalSupply() + amount <= MAX_SUPPLY, 'KRC: Exceeds maximum supply');
    _mint(to, amount);
  }

  /**
   * @dev Burn tokens
   * @param amount Amount to burn
   */
  function burn(uint256 amount) public override validAmount(amount) {
    require(balanceOf(msg.sender) >= amount, 'KRC: Insufficient balance');
    _burn(msg.sender, amount);
  }

  /**
   * @dev Pause token transfers
   */
  function pause() external onlyOwner {
    paused = true;
  }

  /**
   * @dev Unpause token transfers
   */
  function unpause() external onlyOwner {
    paused = false;
  }

  /**
   * @dev Override _update to handle pausing
   */
  function _update(address from, address to, uint256 value) internal override {
    require(!paused, 'KRC: Paused');
    super._update(from, to, value);
  }
}
