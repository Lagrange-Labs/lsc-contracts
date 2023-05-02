pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/token/ERC20/ERC20Upgradeable.sol";

contract WETH9 is ERC20Upgradeable {
    event Deposit(address indexed dst, uint wad);
    event Withdrawal(address indexed src, uint wad);

    function initialize() public initializer {
        __ERC20_init("Wrapped ETH", "WETH");
    }

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        _mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint wad) public {
        require(balanceOf(msg.sender) >= wad);
        _burn(msg.sender, wad);
        payable(msg.sender).transfer(wad);
        emit Withdrawal(msg.sender, wad);
    }
}
