// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

contract ReentrancyGuard {
    bool private _entered;

    modifier nonReentrant() {
        require(!_entered, "ReentrancyGuard: reentrant call");
        _entered = true;
        _;
        _entered = false;
    }
}
