// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../contracts/mock/BLSKeyCheckerMock.sol";

contract BLSKeyCheckerTest is Test {
    BLSKeyCheckerMock blsKeyChecker;

    function setUp() public virtual {
        blsKeyChecker = new BLSKeyCheckerMock();
    }

    function testDeploy() public view {
        console.log("BLSKeyChecker: ", address(blsKeyChecker));
    }

    function testBLSKeyCheck() public {
        address operator = address(0x1);
        uint256 expiry = block.timestamp + 1000;
        bytes32 salt = bytes32("salt");

        bytes32 digestHash = blsKeyChecker.calculateKeyWithProofHash(operator, salt, expiry);
        assertEq(digestHash, bytes32(0xc7b0656c76580037ecdb295dc2853ed637fbe9fa28fb9370b9c46f3af263b153));

        IBLSKeyChecker.BLSKeyWithProof memory keyWithProof;
        keyWithProof.blsG1PublicKeys = new uint256[2][](2);
        keyWithProof.salt = salt;
        keyWithProof.expiry = expiry;
        keyWithProof.blsG1PublicKeys[0] = [
            20545566521870365205556113210563293367690778742407920553261414530195018910715,
            3810931577929286987941494315798961488626940522750116988265143865141196490387
        ];
        keyWithProof.blsG1PublicKeys[1] = [
            6188567693588639773359247442075250301875946893450591291984608313433056322940,
            12540808364665293681985345794763782578142148289057530577303063823278783323510
        ];
        keyWithProof.aggG2PublicKey[0][1] =
            18084767928220623229917970612945789795769398030845769455787446276373185723063;
        keyWithProof.aggG2PublicKey[0][0] =
            16397860365782501839161155343985122599576180614855180919184128444013102341284;
        keyWithProof.aggG2PublicKey[1][1] =
            11404740616800698491602595484707113839683705372417228495600050288329164748570;
        keyWithProof.aggG2PublicKey[1][0] = 6295226055133679941129620269193586277360989159404994532519051774500585286957;
        keyWithProof.signature[0] = 14241513117207009207462807081901324027050753047754368460071596134640222275923;
        keyWithProof.signature[1] = 18004051656820227831367841997927928243949150848123937083522728348263826886221;

        vm.startPrank(operator);
        bool result = blsKeyChecker.checkBLSKeyWithProof(operator, keyWithProof);
        assert(result);
        vm.stopPrank();
    }
}
