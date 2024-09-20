// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {CohortConfiguration} from "../configuration/CohortConfiguration.sol";

interface ICohort is CohortConfiguration {
    function getLastSnapShotTime(uint256) external view returns (uint256);
    function getExactTimeSnapShot(uint256, uint256) external view returns (CohortMetadata memory);
    function getSnapShot(uint256, uint256) external view returns (CohortMetadata memory);
    function ownerOf(uint256) external view returns (address);
    function cohortType(uint256) external view returns (CohortType);
    function metadata(uint256) external view returns (CohortMetadata memory);
    function grant(uint256) external view returns (CohortGrant memory);
    function MAX_GRANT_RATE() external view returns (uint256);
    function GRANT_RATE_DENOMINATOR() external view returns (uint256);
    function mint(CohortMetadata calldata) external returns (uint256);
    function setTokenURI(uint256, string calldata) external;
    function setCohortGrant(uint256, CohortGrant calldata) external;
}
