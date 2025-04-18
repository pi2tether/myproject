// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

contract AccessControl {
    mapping(bytes32 => mapping(address => bool)) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    modifier onlyRole(bytes32 role) {
        require(_roles[role][msg.sender], "AccessControl: not authorized");
        _;
    }

    function grantRole(bytes32 role, address account) public {
        _roles[role][account] = true;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }
}
