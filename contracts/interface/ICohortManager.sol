// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {CohortConfiguration} from "../configuration/CohortConfiguration.sol";

interface ICohortManager is CohortConfiguration {
    function isValidSignature(bytes32, bytes memory) external view returns (bytes4);
    function cohort() external view returns (address);
    function openNameTag() external view returns (address);
    function signerCount() external view returns (uint256);
    function isValidSigner(address) external view returns (bool);
    function cohortCount() external view returns (uint256);
    function ownedCohorts(uint256) external view returns (uint256);
    function setSigner(address, bool) external;
    function mintCohort(CohortMetadata calldata) external returns (uint256, uint256);
    function setCohortGrant(uint256, GrantConfig calldata) external;
    function setTokenURI(uint256, string calldata) external;
}
