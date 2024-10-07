// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC1271} from "@openzeppelin/contracts/interfaces/IERC1271.sol";

import {IOpenIdentityRegistry} from "../interface/IOpenIdentityRegistry.sol";

contract OpenIdentityRegistry is IOpenIdentityRegistry {
    mapping(bytes32 => bool) private _isUsedHash;
    mapping(address => mapping(address => bool)) private _isRevokedBeneficiary;

    function version() external pure returns (string memory) {
        return "OpenIdentityRegistry241002";
    }

    function isUsedHash(bytes32 hash) external view returns (bool) {
        return _isUsedHash[hash];
    }

    function isRevokedBeneficiary(address signer, address beneficiary) external view returns (bool) {
        return _isRevokedBeneficiary[signer][beneficiary];
    }

    event BeneficiaryRevoked(address signer, address beneficiary, bool revoked);
    function revokeBeneficiary(address beneficiary, bool revoked) external {
        _revokeBeneficiary(msg.sender, beneficiary, revoked);
    }

    function revokeBeneficiaryBySignature(address signer, address beneficiary, bool revoked, uint256 validUntil, bytes memory signature) external {
        require(validUntil >= block.timestamp);

        bytes32 hash = keccak256(abi.encode("OpenIdentityRegistry:Revoke", address(this), getChainId(), signer, beneficiary, revoked, validUntil));
        require(!_isUsedHash[hash]);
        _isUsedHash[hash] = true;

        if(signer.code.length == 0) {
            require(signature.length == 65);

            bytes32 signingHash = MessageHashUtils.toEthSignedMessageHash(hash);
            require(signer == ECDSA.recover(signingHash, signature));
        }
        else require(IERC1271(signer).isValidSignature(hash, signature) == IERC1271.isValidSignature.selector);

        _revokeBeneficiary(signer, beneficiary, revoked);
    }

    function _revokeBeneficiary(address signer, address beneficiary, bool revoked) internal {
        _isRevokedBeneficiary[signer][beneficiary] = revoked;
        emit BeneficiaryRevoked(signer, beneficiary, revoked);
    }

    function getChainId() public view returns (uint256 chainId) {
        assembly {
            chainId := chainid()
        }
    }
}
