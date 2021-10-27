// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.7.6;

/// @notice Minimal interface for Moloch DAO v2.
interface IMolochV2minimal { 
    function getProposalFlags(uint256 proposalId) external view returns (bool[6] memory);
    
    function submitProposal(
        address applicant,
        uint256 sharesRequested,
        uint256 lootRequested,
        uint256 tributeOffered,
        address tributeToken,
        uint256 paymentRequested,
        address paymentToken,
        string calldata details
    ) external returns (uint256);
    
    function cancelProposal(uint256 proposalId) external;
    
    function withdrawBalance(address token, uint256 amount) external;
}

/// @notice Minimal interface for wrapped ether v9.
interface IWETHv9minimal {
    function approve(address guy, uint wad) external returns (bool);
    function transfer(address dst, uint wad) external returns (bool);
    function transferFrom(address src, address dst, uint wad) external returns (bool);
    function deposit() external payable;
    function withdraw(uint wad) external;
}

/// @notice Single owner function access control module.
abstract contract LexOwnable {
    event TransferOwner(address indexed from, address indexed to);
    event TransferOwnerClaim(address indexed from, address indexed to);
    
    address public owner;
    address public pendingOwner;

    /// @notice Initialize ownership module for function access control.
    /// @param owner_ Account to grant ownership.
    function init(address owner_) internal {
        owner = owner_;
        emit TransferOwner(address(0), owner_);
    }

    /// @notice Access control modifier that conditions function to be restricted to `owner` account.
    modifier onlyOwner() {
        require(msg.sender == owner, "NOT_OWNER");
        _;
    }

    /// @notice `pendingOwner` can claim `owner` account.
    function claimOwner() external {
        require(msg.sender == pendingOwner, "NOT_PENDING_OWNER");
        emit TransferOwner(owner, msg.sender);
        owner = msg.sender;
        pendingOwner = address(0);
    }

    /// @notice Transfer `owner` account.
    /// @param to Account granted `owner` access control.
    /// @param direct If 'true', ownership is directly transferred.
    function transferOwner(address to, bool direct) external onlyOwner {
        require(to != address(0), "ZERO_ADDRESS");
        
        if (direct) {
            owner = to;
            emit TransferOwner(msg.sender, to);
        } else {
            pendingOwner = to;
            emit TransferOwnerClaim(msg.sender, to);
        }
    }
}

/// @notice Moloch DAO v2 membership proposal tribute manager.
contract MolochTributeManager is LexOwnable {
    event UpdateTribute(uint256 indexed sharesForTribute, uint256 indexed tributeForShares);
    
    /// @dev Use private variables to save gas.
    IMolochV2minimal dao;
    IWETHv9minimal wETH9;
    uint256 sharesForTribute;
    uint256 tributeForShares; 
    
    mapping(uint256 => App) public applications;
    
    struct App {
        address applicant;
        uint256 tribute;
    }
    
    /// @notice Initializes contract.
    /// @param owner_ Account to grant initial ownership role.
    /// @param dao_ Moloch DAO v2 for membership proposals.
    /// @param wETH9_ wETH9-compatible token wrapper for native asset.
    /// @param sharesForTribute_ `DAO` 'shares' requested.
    /// @param tributeForShares_ `DAO` 'tribute' made.
    function init(address owner_, IMolochV2minimal dao_, IWETHv9minimal wETH9_, uint256 sharesForTribute_, uint256 tributeForShares_) external {
        require(address(dao) == address(0), "INITIALIZED");
        
        LexOwnable.init(owner_);
        wETH9_.approve(address(dao_), type(uint256).max);
        dao = dao_;
        wETH9 = wETH9_;
        sharesForTribute = sharesForTribute_;
        tributeForShares = tributeForShares_;
    }
    
    /// @notice Fallback that submits membership proposal to `DAO` and wraps native asset to `wETH9` if not `wETH9` unwrapping.
    receive() external payable {
        if (msg.sender != address(wETH9)) {
            submitMembershipProposal("Membership");
        }
    }
    
    /// @notice Submits membership proposal to `DAO` and wraps native asset to `wETH9`.
    /// @param details Membership details.
    /// @return proposalId # associated with `DAO` proposal.
    function submitMembershipProposal(string memory details) public payable returns (uint256 proposalId) {
        uint256 tribute = tributeForShares;
        
        // If native asset value attached, wrap into `wETH9`.
        if (msg.value > 0) {
            require(msg.value == tribute, "INVALID_TRIBUTE");
            wETH9.deposit{value: msg.value}();
        } else {
            wETH9.transferFrom(msg.sender, address(this), tribute);
        }
        
        // Submit membership proposal with local presets.    
        proposalId = dao.submitProposal(
            msg.sender,
            sharesForTribute,
            0,
            tribute,
            address(wETH9),
            0,
            address(wETH9),
            details
        );
        
        // Store applicant data for cancellations and withdrawals.
        applications[proposalId] = App(msg.sender, tribute);
    }
    
    /// @notice Cancels membership proposal in `DAO` and returns `tribute` deposit to `applicant` in `wETH9` or native asset.
    /// @param proposalId # associated with `DAO` proposal.
    /// @param unwrap Flags whether to return `wETH9` or native asset to `applicant`.
    /// @dev Can only be called by `applicant` associated with `proposalId` if not sponsored.
    function cancelMembershipProposal(uint256 proposalId, bool unwrap) external {
        App storage app = applications[proposalId]; 
        
        require(msg.sender == app.applicant, "NOT_APPLICANT");
        
        // Cancel proposal in `DAO` and withdraw `tribute` deposit.
        dao.cancelProposal(proposalId);
        dao.withdrawBalance(address(wETH9), app.tribute);
        
        if (unwrap) { // unwrap to native asset
            wETH9.withdraw(app.tribute);
            (bool success, ) = msg.sender.call{value: app.tribute}("");
            require(success, "NOT_PAYABLE");
        } else { // or, transfer `wETH9` token
            wETH9.transfer(msg.sender, app.tribute);
        }
    }
    
    /// @notice Withdraws `tribute` deposit from `DAO` for `applicant`.
    /// @param proposalId # associated with `DAO` proposal.
    /// @param unwrap Flags whether to return `wETH9` or native asset to `applicant`.
    /// @dev Can only be called by `applicant` associated with `proposalId` if proposal fails.
    function withdrawProposalTribute(uint256 proposalId, bool unwrap) external {
        App storage app = applications[proposalId]; 
        
        bool[6] memory flags = dao.getProposalFlags(proposalId);
        
        require(msg.sender == app.applicant, "NOT_APPLICANT");
        
        // Check proposal status & withdraw `tribute` deposit.
        require(flags[1], "PROPOSAL_NOT_PROCESSED");
        require(!flags[2], "PROPOSAL_PASSED");
        dao.withdrawBalance(address(wETH9), app.tribute);
        
        if (unwrap) { // unwrap to native asset
            wETH9.withdraw(app.tribute);
            (bool success, ) = msg.sender.call{value: app.tribute}("");
            require(success, "NOT_PAYABLE");
        } else { // or, transfer `wETH9` token
            wETH9.transfer(msg.sender, app.tribute);
        }
    }
    
    /// @notice Updates `wETH9` amount forwarded for `DAO` membership 'tribute' and 'shares' requested.
    /// @param sharesForTribute_ `DAO` 'shares' requested.
    /// @param tributeForShares_ `DAO` 'tribute' made.
    /// @dev Can only be called by `owner`.
    function updateTribute(uint256 sharesForTribute_, uint256 tributeForShares_) external onlyOwner {
        sharesForTribute = sharesForTribute_;
        tributeForShares = tributeForShares_;
        emit UpdateTribute(sharesForTribute_, tributeForShares_);
    }
}

/// @notice EIP-1167 Clone Factory.
/// @author Copyright (c) 2018 Murray Software, LLC,
/// License-Identifier: MIT.
contract CloneFactory {
    /// @notice EIP-1167 proxy pattern.
    function createClone(address payable target) internal returns (address payable result) {
        bytes20 targetBytes = bytes20(target);
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            result := create(0, clone, 0x37)
        }
    }
}

/// @notice Summoner for Moloch DAO v2 membership proposal tribute manager.
contract MolochTributeManagerSummoner is CloneFactory {
    address payable immutable public template;
    
    event SummonMolochTributeManager(address indexed molochTributeManager);
    
    constructor(address payable _template) {
        template = _template;
    }
    
    /// @notice Initializes contract via EIP-1167 cloning.
    /// @param owner_ Account to grant initial ownership role.
    /// @param dao_ Moloch DAO v2 for membership proposals.
    /// @param wETH9_ wETH9-compatible token wrapper for native asset.
    /// @param sharesForTribute_ `DAO` 'shares' requested.
    /// @param tributeForShares_ `DAO` 'tribute' made.
    function summonMolochTributeManager(
        address owner_,
        IMolochV2minimal dao_, 
        IWETHv9minimal wETH9_, 
        uint256 sharesForTribute_, 
        uint256 tributeForShares_
    ) external returns (MolochTributeManager molochTributeManager) {
        molochTributeManager = MolochTributeManager(createClone(template));
        
        molochTributeManager.init(owner_, dao_, wETH9_, sharesForTribute_, tributeForShares_);
        
        emit SummonMolochTributeManager(address(molochTributeManager));
    }
}
