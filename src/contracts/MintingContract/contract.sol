
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

contract MintingContract is ERC20, Ownable2Step {
    uint256 public immutable MAX_SUPPLY;
    uint256 public immutable INITIAL_MINT_LIMIT;
    uint256 public currentMintLimit;

    event MintLimitUpdated(uint256 newLimit);
    event TokensMinted(address to, uint256 amount);

    constructor() ERC20("Custom Token", "CTK") Ownable() {
        MAX_SUPPLY = 10000000 * 10**decimals(); // 10 million tokens
        INITIAL_MINT_LIMIT = 1000000 * 10**decimals(); // Initial mint limit of 1 million tokens
        currentMintLimit = INITIAL_MINT_LIMIT;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        require(to != address(0), "Cannot mint to zero address");
        require(amount > 0, "Amount must be greater than zero");
        require(totalSupply() + amount <= currentMintLimit, "Minting would exceed the current mint limit");
        require(totalSupply() + amount <= MAX_SUPPLY, "Minting would exceed the maximum supply cap");
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    function setMintLimit(uint256 newLimit) public onlyOwner {
        require(
            newLimit >= totalSupply() && newLimit <= MAX_SUPPLY,
            "New limit must be greater than or equal to current total supply and less than or equal to maximum supply"
        );
        currentMintLimit = newLimit;
        emit MintLimitUpdated(newLimit);
    }
}
