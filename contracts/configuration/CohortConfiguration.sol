// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {GrantConfiguration} from "./GrantConfiguration.sol";

interface CohortConfiguration is GrantConfiguration {
    enum CohortType {
        None,
        Address,
        Identity
    }

    struct CohortMetadata {
        CohortType cohortType;
        bytes32 merkleRoot;
        uint256 totalWeight;
        uint256 totalCount;
        string prover;
        uint256[] parentCohort;

        // name, description
        string tokenURI;
    }
}
