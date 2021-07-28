//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import './Royalty.sol';

/// @dev ERC721 contract with royalties
contract ERC721WithRoyalty is ERC721 {
    using Counters for Counters.Counter;

    Counters.Counter private _idTracker;
    Royalty private _royalty;

    uint256 nextTokenId;

    constructor(string memory name_, string memory symbol_)
        ERC721(name_, symbol_)
    {}

    /// @dev Set royalty contract
    /// @param who account of the royalty contract
    function setRoyaltyContract(address who) external {
        _royalty = Royalty(who);
    }

    /// @notice Mint one token to `to`
    /// @param to the recipient of the token
    /// @param royaltyRecipients an array of recipients for royalties (if royaltyValues[i] > 0)
    /// @param royaltyValues an array of royalties asked for (EIP2981)
    function mint(address to, address[] memory royaltyRecipients, uint256[] memory royaltyValues) external {
        require(
            royaltyRecipients.length == royaltyValues.length,
            'ERC721: Arrays length mismatch'
        );

        uint256 tokenId = _idTracker.current();
        _safeMint(to, tokenId, '');
        _royalty.setTokenRoyalty(tokenId, royaltyRecipients, royaltyValues);

        _idTracker.increment();
    }
}
