// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

// accumulation per account
struct Accumulation {
    address[] tokens;
    mapping(address => uint256) balances;
}

// royalty per NFT
struct Royalty {
    address[] beneficiaries;
    mapping(address => uint256) values;
}

struct Proposal {
    uint256 tokenId;
    Royalty royalty;
    uint256 expireAt;
    uint256 endAt;
    mapping(address => bool) agreed;
}

/// @dev This is a contract used to add Royalty to NFT
contract RoyaltyContract is AccessControl {
    using Counters for Counters.Counter;

    uint256 constant PROPOSAL_DEADLINE = 5 days;

    Counters.Counter private _proposalIdTracker;

    mapping(address => Accumulation) private _accumulations; // accumulations for each sale
    mapping(uint256 => Royalty) private _royalties; // royalty per NFT
    mapping(uint256 => Proposal) private _proposals; // proposals

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
                _royalties[tokenId].values[recipients[i]] = values[i];
                _royalties[tokenId].beneficiaries.push(recipients[i]);
            }
        }
    }

    /// @dev Split token royalties
    /// @param tokenId the NFT id of the royalties
    /// @param recipient recipient of the splitted royalties
    /// @param value percentage for split (using 2 decimals - 10000 = 100, 0 = 0)
    function splitTokenRoyalty(uint256 tokenId, address recipient, uint256 value) external {
        require(recipient != address(0), 'Royalty: Invalid recipient address');
        require(value > 0, 'Royalty: Value should be greater than 0');
        require(value <= 10000, 'Royalty: Too high value');
        require(_royalties[tokenId].values[msg.sender] > 0, 'Royalty: Sender is not royalty account');
        require(_royalties[tokenId].values[msg.sender] > value, 'Royalty: Sender does not have enough royalty');

        _royalties[tokenId].values[msg.sender] = _royalties[tokenId].values[msg.sender] - value;
        _royalties[tokenId].values[recipient] = value;
        _royalties[tokenId].beneficiaries.push(recipient);
    }

    /// @dev Return royalty value of msg.sender for the token
    /// @param tokenId the NFT id of the royalties
    function royaltyInfo(uint256 tokenId) external view returns (uint256) {
        return _royalties[tokenId].values[msg.sender];
    }

    /// @dev Calculate and accumulate royalty value of each beneficiary for the token and sale price
    /// @param tokenId the NFT id of the royalties
    /// @param saleToken address of erc20 token used in sale
    /// @param salePrice sale price of the NFT
    function afterSale(uint256 tokenId, address saleToken, uint256 salePrice) external {
        require(salePrice > 0, 'Royalty: Sale price should be greater than 0');
        for (uint256 i; i < _royalties[tokenId].beneficiaries.length; i++) {
            if (_royalties[tokenId].values[_royalties[tokenId].beneficiaries[i]] > 0) {
                if (_accumulations[_royalties[tokenId].beneficiaries[i]].balances[saleToken] == 0) {
                    _accumulations[_royalties[tokenId].beneficiaries[i]].tokens.push(saleToken);
                }
                _accumulations[_royalties[tokenId].beneficiaries[i]].balances[saleToken] += salePrice * _royalties[tokenId].values[_royalties[tokenId].beneficiaries[i]] / 10000;
            }
        }
    }

    /// @notice should approve to transfer erc20 by this contract
    /// @dev withdraw royalty of msg.sender for the token and sale price
    /// @param token address of erc20 token used in sale
    /// @param amount amount of the erc20 token
    function withdraw(address token, uint256 amount, address to) external {
        require(amount > 0, 'Royalty: Invalid withdraw amount');
        require(token != address(0), 'Royalty: Invalid token');
        require(to != address(0), 'Royalty: Invalid withdraw address');
        require(_accumulations[msg.sender].balances[token] >= amount, 'Royalty: Insufficient accumulation');

        require(
            IERC20(token).balanceOf(msg.sender) >= amount,
            'Royalty: Insufficient sale token balance to withdraw'
        );
        require(
            IERC20(token).allowance(msg.sender, address(this)) >= amount,
            'Royalty: Please approve to transfer ERC20'
        );

        _accumulations[msg.sender].balances[token] -= amount;
        IERC20(token).transferFrom(msg.sender, to, amount);
    }

    /// @dev Proposal royalties
    /// @param tokenId the NFT id of the royalties
    /// @param recipients array of recipient of the royalties
    /// @param values array of percentage (using 2 decimals - 10000 = 100, 0 = 0)
    function propose(uint256 tokenId, address[] memory recipients, uint256[] memory values) external {
        require(
            recipients.length == values.length,
            'ERC721: Arrays length mismatch'
        );
        require(_royalties[tokenId].values[msg.sender] > 0, 'Royalty: Sender is not royalty account');

        uint256 proposalId = _proposalIdTracker.current();
        _proposals[proposalId + 1].tokenId = tokenId;
        for (uint256 i; i < recipients.length; i++) {
            if (values[i] > 0 && values[i] <= 10000) {
                _proposals[proposalId + 1].royalty.values[recipients[i]] = values[i];
                _proposals[proposalId + 1].royalty.beneficiaries.push(recipients[i]);
            } else if (values[i] == 0) {
                _proposals[proposalId + 1].agreed[recipients[i]] = true;
            }
        }
        _proposals[proposalId + 1].expireAt = block.timestamp + PROPOSAL_DEADLINE;

        _proposalIdTracker.increment();
    }

    /// @dev Vote to proposal
    /// @param proposalId id of the proposal
    /// @param agreed agreement to proposal
    function vote(uint256 proposalId, bool agreed) external {
        require(proposalId > 0, 'Royalty: Invalid proposal id');
        require(_proposals[proposalId].expireAt > 0, 'Royalty: Invalid proposal');
        require(_proposals[proposalId].expireAt > block.timestamp, 'Royalty: Expired proposal');
        require(_proposals[proposalId].royalty.values[msg.sender] > 0, 'Royalty: Sender is not royalty account');
        require(_proposals[proposalId].endAt == 0, 'Royalty: Proposal already ended');

        _proposals[proposalId].agreed[msg.sender] = agreed;
        if (agreed) {
            for (uint256 i; i < _proposals[proposalId].royalty.beneficiaries.length; i++) {
                if (_proposals[proposalId].agreed[_proposals[proposalId].royalty.beneficiaries[i]] == false) {
                    return; // return if any disagreed participant
                }
            }
            _royalties[_proposals[proposalId].tokenId].beneficiaries = _proposals[proposalId].royalty.beneficiaries;
            for (uint256 i; i < _proposals[proposalId].royalty.beneficiaries.length; i++) {
                _royalties[_proposals[proposalId].tokenId].values[_proposals[proposalId].royalty.beneficiaries[i]] = _proposals[proposalId].royalty.values[_proposals[proposalId].royalty.beneficiaries[i]];
            }
            _proposals[proposalId].endAt = block.timestamp;
        }
    }
}
