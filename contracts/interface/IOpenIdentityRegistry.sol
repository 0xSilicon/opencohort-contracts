// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IOpenIdentityRegistry {
    function isUsedHash(bytes32) external view returns (bool);
    function isRevokedBeneficiary(address, address) external view returns (bool);
    function revokeBeneficiary(address, bool) external;
    function revokeBeneficiaryBySignature(address, address, bool, uint256, bytes calldata) external;
}
