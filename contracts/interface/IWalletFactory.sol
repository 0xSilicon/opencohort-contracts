// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {WalletInfo} from "../namedWallet/NamedWallet.sol";

interface IWalletFactory {
    function deployWallet(address virtualAddress, WalletInfo memory walletInfo, string[] calldata keys, string[] calldata values) external returns (address);
    function activateWallet(address signer, address virtualAddress, address owner, bytes calldata signature) external;
    function computeAddress(address signer, address virtualAddress) external view returns (address);
}
