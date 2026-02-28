// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestUSDT is ERC20 {
    constructor() ERC20("Test USDT", "TUSDT") {
        _mint(msg.sender, 1000000 * 10**6); // 1M test USDT
    }
    
    function decimals() public pure override returns (uint8) {
        return 6;
    }
    
    // Add this for easier testing
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
