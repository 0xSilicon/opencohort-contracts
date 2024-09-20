// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IOpenNameTag {
    struct NameTagMetadata {
        string name;
        string description;
        string image;
    }

    function mint(NameTagMetadata calldata, string[] calldata, string[] calldata) external;
    function setNameTagMetadata(NameTagMetadata calldata) external;
    function addPropertyBatch(string[] calldata, string[] calldata) external;
    function removeProperty(string calldata) external;
}
