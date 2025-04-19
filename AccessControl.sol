pragma solidity ^0.6.6;

contract AccessControl {
    mapping(address => bool) internal _a;

    function isAuthorized(address x) public view returns (bool) {
        return _a[x];
    }

    function addRole(address x) public {
        _a[x] = true;
    }

    function removeRole(address x) public {
        _a[x] = false;
    }
}
