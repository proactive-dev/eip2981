// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/// @dev This is a contract used to add Royalty to NFT
contract Royalty is AccessControl {
    mapping(uint256 => mapping(address => uint256)) internal _royalties;

    modifier onlyAdmin {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Royalty: Admin only");
        _;
    }

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /// @dev Grant admin role to an account
    /// @param who account for granting admin role
    function setAdmin(address who) external onlyAdmin {
        grantRole(DEFAULT_ADMIN_ROLE, who);
    }

    /// @dev Sets token royalties
    /// @param tokenId the NFT id of the royalties
    /// @param recipients array of recipient of the royalties
    /// @param values array of percentage (using 2 decimals - 10000 = 100, 0 = 0)
    function setTokenRoyalty(uint256 tokenId, address[] memory recipients, uint256[] memory values) external onlyAdmin {
        for (uint256 i; i < recipients.length; i++) {
            if (values[i] > 0 && values[i] <= 10000) {
                _royalties[tokenId][recipients[i]] = values[i];
            }
        }
    }

    /// @dev Split token royalties
    /// @param tokenId the NFT id of the royalties
    /// @param recipient recipient of the splitted royalties
    /// @param value percentage for split (using 2 decimals - 10000 = 100, 0 = 0)
    function splitTokenRoyalty(uint256 tokenId, address recipient, uint256 value) external {
        require(value > 0, 'Royalty: Value should be greater than zero');
        require(value <= 10000, 'Royalty: Too high value');
        require(_royalties[tokenId][msg.sender] > 0, 'Royalty: Sender is not royalty account');
        require(_royalties[tokenId][msg.sender] > value, 'Royalty: Sender does not have enough royalty');

        _royalties[tokenId][msg.sender] = _royalties[tokenId][msg.sender] - value;
        _royalties[tokenId][recipient] = value;
    }

    /// @dev Return royalty value of msg.sender for the token and sale price
    /// @param tokenId the NFT id of the royalties
    /// @param salePrice sale price of the NFT
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (uint256)
    {
        return salePrice * _royalties[tokenId][msg.sender] / 10000;
    }

    /// @notice should approve to transfer erc20 by this contract
    /// @dev withdraw royalty of msg.sender for the token and sale price
    /// @param tokenId the NFT id of the royalties
    /// @param saleToken address of erc20 token used in sale
    /// @param salePrice sale price of the NFT
    function withdraw(uint256 tokenId, address saleToken, uint256 salePrice, address to) external {
        require(_royalties[tokenId][msg.sender] > 0, 'Royalty: Sender is not royalty account');
        require(saleToken != address(0), 'Royalty: Invalid sale token');
        require(to != address(0), 'Royalty: Invalid withdraw address');

        uint256 royaltyAmount = salePrice * _royalties[tokenId][msg.sender] / 10000;
        require(IERC20(saleToken).balanceOf(msg.sender) >= royaltyAmount, 'Royalty: Insufficient sale token balance to withdraw');
        require(IERC20(saleToken).allowance(msg.sender, address(this)) >= royaltyAmount, 'Royalty: Please approve to transfer ERC20');

        IERC20(saleToken).transferFrom(msg.sender, to, royaltyAmount);
    }
}
