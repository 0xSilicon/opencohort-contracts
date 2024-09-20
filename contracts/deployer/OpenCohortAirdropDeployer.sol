// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IOpenCohortAirdropDeployer} from "../interface/IOpenCohortAirdropDeployer.sol";
import {OpenCohortAirdrop} from "../airdrop/OpenCohortAirdrop.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract OpenCohortAirdropDeployer is Ownable, UUPSUpgradeable, IOpenCohortAirdropDeployer {
    using SafeERC20 for IERC20;

    address public cohort;

    uint256 public openCohortAirdropCount;
    mapping(uint256 => address) public openCohortAirdropList;
    mapping(address => bool) public isValidOpenCohortAirdrop;

    address public airdropImplementation;

    constructor() Ownable(address(0xdead)) { cohort = address(1); }

    function version() external pure returns (string memory) {
        return "OpenCohortAirdropDeployer240819A";
    }

    function initialize(address owner_, address cohort_) external {
        require(cohort == address(0));

        _transferOwnership(owner_);
        cohort = cohort_;

        airdropImplementation = address(new OpenCohortAirdrop());
    }

    event SetAirdropImplementation(address airdropImplementation);
    function setAirdropImplementation() external onlyOwner {
        airdropImplementation = address(new OpenCohortAirdrop());
        emit SetAirdropImplementation(airdropImplementation);
    }

    event DeployOpenCohortAirdrop(address deployer, address openCohortAirdrop, OpenCohortAirdropConfig openCohortAirdropConfig, uint256 cohortId, uint256 cohortTime);
    function deployOpenCohortAirdrop(
        OpenCohortAirdropConfig calldata openCohortAirdropConfig,
        uint256 cohortId,
        uint256 cohortTime
    ) external returns (address) {
        require(openCohortAirdropConfig.rewardType != RewardType.None);
        require(openCohortAirdropConfig.token != address(0));
        require(openCohortAirdropConfig.totalAmount != 0);
        require(openCohortAirdropConfig.claimableTime >= block.timestamp);

        if(openCohortAirdropConfig.rewardType == RewardType.Constant || openCohortAirdropConfig.rewardType == RewardType.Unit){
            require(openCohortAirdropConfig.amountPer != 0);
            require(openCohortAirdropConfig.amountPer <= openCohortAirdropConfig.totalAmount);
        }

        address owner = msg.sender;
        address openCohortAirdrop = address(new ERC1967Proxy(
            airdropImplementation,
            abi.encodeCall(OpenCohortAirdrop.initialize, (owner, cohort, openCohortAirdropConfig, cohortId, cohortTime))
        ));
        emit DeployOpenCohortAirdrop(owner, openCohortAirdrop, openCohortAirdropConfig, cohortId, cohortTime);

        isValidOpenCohortAirdrop[openCohortAirdrop] = true;
        openCohortAirdropList[openCohortAirdropCount] = openCohortAirdrop;
        openCohortAirdropCount += 1;

        IERC20(openCohortAirdropConfig.token).safeTransferFrom(owner, openCohortAirdrop, openCohortAirdropConfig.totalAmount);

        return openCohortAirdrop;
    }

    function _authorizeUpgrade(address newImplementation) internal view override {
        (newImplementation);
        _checkOwner();
    }
}
