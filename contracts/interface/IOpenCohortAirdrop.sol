// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {OpenCohortAirdropConfiguration} from "../configuration/OpenCohortAirdropConfiguration.sol";
import {CohortConfiguration} from "../configuration/CohortConfiguration.sol";

interface IOpenCohortAirdrop is OpenCohortAirdropConfiguration, CohortConfiguration {
    function setCohortId(uint256) external;
    function setCohortTime(uint256) external;
    function setBaseURI(string calldata) external;
    function setImage(string calldata) external;
    function claimableTime() external view returns (uint256);
    function image() external view returns (string memory);
}
