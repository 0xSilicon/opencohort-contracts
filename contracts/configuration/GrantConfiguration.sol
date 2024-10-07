// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface GrantConfiguration {
    struct GrantConfig {
        uint256 rate;
        address grantee;
    }
}
