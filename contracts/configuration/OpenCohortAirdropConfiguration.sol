// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {GrantConfiguration} from "./GrantConfiguration.sol";

interface OpenCohortAirdropConfiguration is GrantConfiguration {
    enum RewardType {
        None,
        Weight,
        Count,
        Constant,
        Unit
    }

    struct OpenCohortAirdropConfig {
        RewardType rewardType;

        address token;
        uint256 totalAmount;
        uint256 claimableTime;

        uint256 amountPer;
        address signer;

        string name;
        string description;
        string image;

        string baseURI;
    }
}
