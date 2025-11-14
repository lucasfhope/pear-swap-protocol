// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Test-only ERC20 that reenters during transferFrom
contract ReentrantERC20 is ERC20 {
    address public reentryTarget; 
    bytes4  public reentrySelector;
    bool    public reentryEnabled;
    bool    internal entered;

    event ReentrancyAttempt(bool success, bytes data);
    constructor() ERC20("Reentrant20", "RE20") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function configureReentry(address target, bytes4 selector, bool enabled) external {
        reentryTarget   = target;
        reentrySelector = selector;
        reentryEnabled  = enabled;
    }

    // Inject reentrancy before the actual transfer accounting occurs.
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (!entered && reentryEnabled && reentryTarget != address(0) && reentrySelector != bytes4(0)) {
            entered = true;
            (bool success, bytes memory data) = reentryTarget.call(abi.encodeWithSelector(reentrySelector, to));
            emit ReentrancyAttempt(success, data);
        }
        return super.transferFrom(from, to, amount);
    }
}

