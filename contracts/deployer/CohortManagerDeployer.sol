// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {CohortManager} from "../utils/CohortManager.sol";

contract CohortManagerDeployer is Ownable, UUPSUpgradeable, Initializable {
    address private _cohort;
    address private _openNameTag;
    address private _cohortManagerImplementation;

    mapping(address => address) private _cohortManager;

    constructor() Ownable(address(0xdead)) {
        _disableInitializers();
    }

    function version() external pure returns (string memory) {
        return "CohortManagerDeployer241024";
    }

    function initialize(address owner_, address cohort_, address openNameTag_) public initializer {
        require(owner() == address(0));
        _transferOwnership(owner_);

        _cohort = cohort_;
        _openNameTag = openNameTag_;

        _cohortManagerImplementation = address(new CohortManager());
    }

    function cohort() public view returns (address) {
        return _cohort;
    }

    function openNameTag() public view returns (address) {
        return _openNameTag;
    }

    function cohortManagerImplementation() public view returns (address) {
        return _cohortManagerImplementation;
    }

    function cohortManager(address ownerOfManager) public view returns (address) {
        return _cohortManager[ownerOfManager];
    }

    event SetCohortManagerImplementation(address cohortManagerImplementation);
    function setCohortManagerImplementation() external onlyOwner {
        _cohortManagerImplementation = address(new CohortManager());
        emit SetCohortManagerImplementation(_cohortManagerImplementation);
    }

    event DeployCohortManager(address ownerOfManager, address cohortManager);
    function deployCohortManager() external {
        address ownerOfManager = msg.sender;
        require(cohortManager(ownerOfManager) == address(0));

        address cohortManager_ = address(new ERC1967Proxy(
            cohortManagerImplementation(),
            abi.encodeCall(CohortManager.initialize, (ownerOfManager, cohort(), openNameTag()))
        ));
        _cohortManager[ownerOfManager] = cohortManager_;

        emit DeployCohortManager(ownerOfManager, cohortManager_);
    }

    function _authorizeUpgrade(address newImplementation) internal view override {
        (newImplementation);
        _checkOwner();
    }
}
