
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MintingContract is ERC20, Ownable {
    uint256 public mintLimit;

    event MintLimitUpdated(uint256 newLimit);
    event TokensMinted(address to, uint256 amount);

    constructor() ERC20("Custom Token", "CTK") Ownable() {
        mintLimit = 1000000 * 10**decimals(); // Initial mint limit of 1 million tokens
    }

    function mint(address to, uint256 amount) public onlyOwner {
        require(totalSupply() + amount <= mintLimit, "Minting would exceed the current mint limit");
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    function setMintLimit(uint256 newLimit) public onlyOwner {
        require(newLimit >= totalSupply(), "New limit cannot be less than current total supply");
        mintLimit = newLimit;
        emit MintLimitUpdated(newLimit);
    }

    function increaseTotalSupply(uint256 amount) public onlyOwner {
        uint256 newLimit = mintLimit + amount;
        setMintLimit(newLimit);
    }
}
