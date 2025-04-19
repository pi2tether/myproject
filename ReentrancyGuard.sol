
pragma solidity ^0.6.6;

contract ReentrancyGuard {
    bool private _r;

    modifier nonReentrant() {
        require(!_r, "ReentrancyGuard: reentrant call");
        _r = true;
        _;
        _r = false;
    }
}
