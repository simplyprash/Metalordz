//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Authorizable.sol";

contract MetalordzGold is ERC20, Authorizable {
    string private TOKEN_NAME = "Metalordz Gold";
    string private TOKEN_SYMBOL = "GOLD";

    event Minted(address owner, uint256 GoldAmt);
    event Burned(address owner, uint256 GoldAmt);

    mapping(address => bool) public authorizedToMint;

    // Constructor
    constructor() ERC20(TOKEN_NAME, TOKEN_SYMBOL) {
        _mint(msg.sender, 200000000 * 10 ** 18);
        emit Minted(msg.sender, 200000000 * 10 ** 18);
    }

    receive() external payable {}

    function burn(uint256 amount) external onlyAuthorized {
        require(balanceOf(address(this)) >= amount, "NOT ENOUGH SILVER");
        _burn(address(this), amount);
        emit Burned(address(this), amount);
    }
}
