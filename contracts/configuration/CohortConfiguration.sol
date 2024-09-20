// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface CohortConfiguration {
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

    struct CohortGrant {
        uint256 rate;
        address grantee;
    }
}
