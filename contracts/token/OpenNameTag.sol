// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC5192} from "../interface/IERC5192.sol";
import {Base64} from '@openzeppelin/contracts/utils/Base64.sol';
import {StringEscape} from '../utils/StringEscape.sol';

contract OpenNameTag is ERC165, IERC5192, IERC721Errors {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event MetadataUpdate(uint256 _tokenId);

    uint256 public immutable MAX_PROPERTY_COUNT;

    string private _name;
    string private _symbol;

    address[] internal _tokens = [address(0x0)];
    address[] private _ownerList;
    mapping(address => uint256) private _tokenIds;
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;

    struct NameTagMetadata {
        string name;
        string description;
        string image;
    }
    mapping(uint256 => NameTagMetadata) private _metadata;

    mapping(uint256 => uint256) private _propertyCount;
    mapping(uint256 => mapping(uint256 => string)) private _propertyKeyList;
    mapping(uint256 => mapping(string => bool)) private _usedProperty;
    mapping(uint256 => mapping(string => string)) private _properties;

    constructor(uint256 maxPropertyCount) { 
        _name = "OpenNameTagImplementation";

        require(maxPropertyCount != 0);
        MAX_PROPERTY_COUNT = maxPropertyCount;
    }

    function initialize(string calldata chain) external {
        require(bytes(_name).length == 0);
        _name = string(abi.encodePacked("Open ", chain, " Name Tag"));
        _symbol = string(abi.encodePacked("M", bytes(chain)[:1], "NT"));
        _tokens.push(address(0));
    }

    receive() external payable { revert(); }

    function version() external pure returns (string memory) {
        return "OpenNameTag240726";
    }

    //////////////////////////////////////////////////////////////////
    // ERC5192 Interface
    function locked(uint256) external pure returns (bool) { return true; }
    //////////////////////////////////////////////////////////////////

    //////////////////////////////////////////////////////////////////
    // ERC721 Interface
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IERC5192).interfaceId ||
            interfaceId == bytes4(0x49064906) ||
            super.supportsInterface(interfaceId);
    }

    function totalMinted() public view returns (uint256) {
        return _tokens.length - 1;
    }

    function totalSupply() public view returns (uint256) {
        return totalMinted();
    }

    function balanceOf(address owner) public view virtual returns (uint256) {
        if (owner == address(0)) {
            revert ERC721InvalidOwner(address(0));
        }
        return _balances[owner];
    }

    function getOwnerListLength() public view returns (uint256) {
        return _ownerList.length;
    }

    function getOwnerByIndex(uint256 idx) public view returns (address) {
        return _ownerList[idx];
    }

    function ownerOf(uint256 tokenId) public view virtual returns (address) {
        return _requireOwned(tokenId);
    }

    function tokenIdOf(address owner) public view returns (uint256) {
        return _requireMinted(owner);
    }

    function propertyCount(uint256 tokenId) public view returns (uint256) {
        require(tokenId != 0);
        return _propertyCount[tokenId];
    }

    function propertyKey(uint256 tokenId, uint256 idx) public view returns (string memory) {
        require(tokenId != 0);
        require(propertyCount(tokenId) > idx);
        return _propertyKeyList[tokenId][idx];
    }

    function property(uint256 tokenId, string memory key) public view returns (string memory) {
        require(tokenId != 0);
        return _requireUsedProperty(tokenId, key);
    }

    function _requireUsedProperty(uint256 tokenId, string memory key) internal view returns (string memory) {
        require(_usedProperty[tokenId][key]);
        return _properties[tokenId][key];
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function baseURI() public view virtual returns (string memory) {
        return "";
    }

    function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
        require(tokenId != 0);
        require(_owners[tokenId] != address(0));

        NameTagMetadata memory nameTagMetadata = _metadata[tokenId];

        bytes memory attributes;
        uint256 tokenPropertyCount = _propertyCount[tokenId];
        if(tokenPropertyCount == 0){
            attributes = bytes('"}');
        }
        else{
            attributes = bytes('","attributes":[');
            for(uint256 i = 0; i < tokenPropertyCount; i++){
                string memory key = _propertyKeyList[tokenId][i];
                string memory value = _properties[tokenId][key];
                string memory end = i == (tokenPropertyCount - 1) ? '"}]}' : '"},';
                bytes memory attribute = abi.encodePacked(
                    '{"trait_type":"',
                    StringEscape.escapeJSON(key, false),
                    '","value":"',
                    StringEscape.escapeJSON(value, false),
                    end
                );

                attributes = abi.encodePacked(
                    attributes,
                    attribute
                );
            }
        }

        return string(abi.encodePacked(
            'data:application/json;base64,',
            Base64.encode(
                abi.encodePacked(
                    '{"name":"',
                    StringEscape.escapeJSON(nameTagMetadata.name, false),
                    '", "description":"',
                    StringEscape.escapeJSON(nameTagMetadata.description, false),
                    '", "image":"',
                    StringEscape.escapeJSON(nameTagMetadata.image, false),
                    attributes
                )
            )
        ));
    }

    function metadata(uint256 tokenId) public view returns (NameTagMetadata memory) {
        require(tokenId != 0);
        require(_owners[tokenId] != address(0));

        return _metadata[tokenId];
    }

    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        return _owners[tokenId];
    }

    function _requireOwned(uint256 tokenId) internal view returns (address) {
        address owner = _ownerOf(tokenId);
        if (owner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
        return owner;
    }

    function _requireMinted(address owner) internal view returns (uint256) {
        uint256 tokenId = _tokenIdOf(owner);
        if(tokenId == 0){
            revert ERC721InvalidOwner(owner);
        }
        return tokenId;
    }

    function _tokenIdOf(address owner) public view returns (uint256) {
        return _tokenIds[owner];
    }

    function _mint(address to) internal returns (uint256) {
        uint256 tokenId = _tokens.length;
        _tokens.push(to);
        _ownerList.push(to);
        _tokenIds[to] = tokenId;
        _owners[tokenId] = to;
        _balances[to] += 1;

        emit Locked(tokenId);
        emit Transfer(address(0), to, tokenId);

        return tokenId;
    }

    function mint(NameTagMetadata memory nameTagMetadata, string[] memory keys, string[] memory values) external {
        require(balanceOf(msg.sender) == 0);
        require(keys.length == values.length);

        uint256 tokenId = _mint(msg.sender);

        _setNameTagMetadata(tokenId, nameTagMetadata);
        for(uint256 i = 0; i < keys.length; i++){
            _addProperty(tokenId, keys[i], values[i]);           
        }
    }

    function setNameTagMetadata(NameTagMetadata memory nameTagMetadata) external {
        address user = msg.sender;
        uint256 tokenId = _requireMinted(user);
        _setNameTagMetadata(tokenId, nameTagMetadata);

        emit MetadataUpdate(tokenId);
        emit Transfer(user, user, tokenId);
    }

    event SetNameTagMetadata(uint256 tokenId, NameTagMetadata nameTagMetadata);
    function _setNameTagMetadata(uint256 tokenId, NameTagMetadata memory nameTagMetadata) internal {
        _metadata[tokenId] = nameTagMetadata;
        emit SetNameTagMetadata(tokenId, nameTagMetadata);
    }

    function addProperty(string memory key, string memory value) external {
        address user = msg.sender;
        uint256 tokenId = _requireMinted(user);
        _addProperty(tokenId, key, value);

        emit MetadataUpdate(tokenId);
        emit Transfer(user, user, tokenId);
    }

    function addPropertyBatch(string[] memory keys, string[] memory values) external {
        require(keys.length == values.length);
        address user = msg.sender;
        uint256 tokenId = _requireMinted(user);
        for(uint256 i = 0; i < keys.length; i++){
            _addProperty(tokenId, keys[i], values[i]);
        }

        emit MetadataUpdate(tokenId);
        emit Transfer(user, user, tokenId);
    }

    event AddProperty(uint256 tokenId, string key, string value);
    function _addProperty(uint256 tokenId, string memory key, string memory value) internal {
        require(!_usedProperty[tokenId][key]);
        _usedProperty[tokenId][key] = true;

        uint256 tokenPropertyCount = propertyCount(tokenId);
        require(tokenPropertyCount < MAX_PROPERTY_COUNT);
        _propertyKeyList[tokenId][tokenPropertyCount] = key;
        _propertyCount[tokenId] = tokenPropertyCount + 1;
        _properties[tokenId][key] = value;

        emit AddProperty(tokenId, key, value);
    }

    function removeProperty(string memory key) external {
        address user = msg.sender;
        uint256 tokenId = _requireMinted(user);
        _removeProperty(tokenId, key);

        emit MetadataUpdate(tokenId);
        emit Transfer(user, user, tokenId);
    }

    event RemoveProperty(uint256 tokenId, string key);
    function _removeProperty(uint256 tokenId, string memory key) internal {
        require(_usedProperty[tokenId][key]);
        _usedProperty[tokenId][key] = false;
        delete _properties[tokenId][key];

        uint256 tokenPropertyCount = propertyCount(tokenId);
        require(tokenPropertyCount != 0);
        
        uint256 idx = 0;
        for(idx = 0; idx < tokenPropertyCount; idx++){
            if(keccak256(bytes(_propertyKeyList[tokenId][idx])) == keccak256(bytes(key))) break;
        }
        require(idx != tokenPropertyCount);

        uint256 newTokenPropertyCount = tokenPropertyCount - 1;
        _propertyKeyList[tokenId][idx] = _propertyKeyList[tokenId][newTokenPropertyCount];
        delete _propertyKeyList[tokenId][newTokenPropertyCount];
        _propertyCount[tokenId] = newTokenPropertyCount;

        emit RemoveProperty(tokenId, key);
    }

    event ModifyProperty(uint256 tokenId, string key, string oldValue, string newValue);
    function modifyProperty(string memory key, string memory value) external {
        address user = msg.sender;
        uint256 tokenId = _requireMinted(user);

        require(_usedProperty[tokenId][key]);
        emit ModifyProperty(tokenId, key, _properties[tokenId][key], value);
        _properties[tokenId][key] = value;

        emit MetadataUpdate(tokenId);
        emit Transfer(user, user, tokenId);
    }
}
