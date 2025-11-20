// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FeeOnTransferERC20Mock is ERC20 {
    /// @notice Fee in basis points. 100 = 1%.
    uint256 constant FEE_BPS = 300;
    uint256 constant BPS_DIVISOR = 10_000;
    address constant FEE_RECIPIENT = address(1001);

    constructor() ERC20("Fee On Transfer Token", "FOT") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /// @dev OpenZeppelin v5 uses `_update` instead of `_transfer`
    function _update(address from, address to, uint256 value) internal override {
        if (from == address(0) || to == address(0)) {
            super._update(from, to, value);
            return;
        }

        uint256 fee = (value * FEE_BPS) / BPS_DIVISOR;
        uint256 amountAfterFee = value - fee;

        super._update(from, FEE_RECIPIENT, fee);
        super._update(from, to, amountAfterFee);
    }
}
