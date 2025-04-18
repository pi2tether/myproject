// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

contract Ownable {
    address private _owner;

    constructor(address deployer) public {
        _owner = deployer;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }

    function getOwner() public view returns (address) {
        return _owner;
    }
}
