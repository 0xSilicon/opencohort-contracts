// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {OpenCohortAirdropConfiguration} from "../configuration/OpenCohortAirdropConfiguration.sol";

interface IOpenCohortAirdropDeployer is OpenCohortAirdropConfiguration {
    function deployOpenCohortAirdrop(OpenCohortAirdropConfig calldata, uint256, uint256) external returns (address);
}
