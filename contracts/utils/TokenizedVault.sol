// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {ITokenizedVault} from "./interfaces/ITokenizedVault.sol";

contract TokenizedVault is ITokenizedVault, Initializable, ERC165 {
    address public basedToken;

    address public policyAdmin;
    mapping(address => bool) public spendableAdmin;
    mapping(address => bool) public transferableAdmin;

    constructor() {}

    function version() external pure returns (string memory) {
        return "TokenizedVault250106A";
    }

    event Initialize(address basedToken, address policyAdmin);
    function initialize(address _basedToken, address _policyAdmin) public initializer {
        require(_basedToken != address(0));
        basedToken = _basedToken;

        _setPolicyAdmin(_policyAdmin);

        emit Initialize(_basedToken, _policyAdmin);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return
            interfaceId == type(ITokenizedVault).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    ///////////////////////////////////////////////////////////////////////
    // Admin
    modifier onlyPolicyAdmin {
        require(msg.sender == policyAdmin);
        _;
    }

    function setPolicyAdmin(address admin) external onlyPolicyAdmin {
        _setPolicyAdmin(admin);
    }

    event SetPolicyAdmin(address admin);
    function _setPolicyAdmin(address admin) internal {
        require(admin != address(0));
        policyAdmin = admin;
        emit SetPolicyAdmin(admin);
    }

    event SetSpendableAdmin(address admin, bool valid);
    function setSpendableAdmin(address admin, bool valid) external onlyPolicyAdmin {
        require(admin != address(0));
        spendableAdmin[admin] = valid;
        emit SetSpendableAdmin(admin, valid);
    }

    function setTransferableAdmin(address admin, bool valid) external onlyPolicyAdmin {
        _setTransferableAdmin(admin, valid);
    }

    function setTransferableAdminBatch(address[] memory adminList, bool[] memory validList) external onlyPolicyAdmin {
        uint256 listLen = adminList.length;
        require(validList.length == listLen);

        for(uint256 i = 0; i < listLen; i++){
            _setTransferableAdmin(adminList[i], validList[i]);
        }
    }

    event SetTransferableAdmin(address admin, bool valid);
    function _setTransferableAdmin(address admin, bool valid) internal {
        require(admin != address(0));
        transferableAdmin[admin] = valid;
        emit SetTransferableAdmin(admin, valid);
    }

    ///////////////////////////////////////////////////////////////////////
    // ERC20
    function name() external view returns (string memory) {
        return IERC20Metadata(basedToken).name();
    }

    function symbol() external view returns (string memory) {
        return IERC20Metadata(basedToken).symbol();
    }

    function decimals() external view returns (uint8) {
        return IERC20Metadata(basedToken).decimals();
    }

    function totalSupply() external view returns (uint256) {
        return IERC20Metadata(basedToken).totalSupply();
    }

    function balanceOf(address account) external view returns (uint256) {
        if(!transferableAdmin[account] && !spendableAdmin[account]) return 0;

        return IERC20Metadata(basedToken).balanceOf(address(this));
    }

    function allowance(address, address) external view returns (uint256) {
        return IERC20Metadata(basedToken).totalSupply();
    }

    event Approved(address admin, address spender, uint256 value);
    function approve(address spender, uint256 value) external returns (bool) {
        address admin = tx.origin;
        if(!spendableAdmin[admin]) return false;

        emit Approved(admin, spender, value);
        return true;
    }

    event Transferred(address admin, address to, uint256 value);
    function transfer(address to, uint256 value) external returns (bool) {
        address admin = msg.sender;
        if(!transferableAdmin[admin]) return false;

        emit Transferred(admin, to, value);
        return IERC20Metadata(basedToken).transfer(to, value);
    }

    event TransferredFrom(address admin, address from, address to, uint256 value);
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        address admin = tx.origin;
        if(!spendableAdmin[admin]) return false;

        emit TransferredFrom(admin, from, to, value);
        return true;
    }
}
