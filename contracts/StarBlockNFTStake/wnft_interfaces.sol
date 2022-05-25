// SPDX-License-Identifier: MIT
// StarBlock Contracts

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";

interface IWrappedNFT is IERC2981, IERC721Metadata {
    event SetAdmin(address _admin);
    event Deposit(address indexed _forUser, uint256[] _tokenIds);
    event Withdraw(address indexed _forUser, uint256[] _wnftTokenIds);

    function admin() external view returns (address);

    function nft() external view returns (IERC721Metadata);
    function deposit(address _forUser, uint256[] memory _tokenIds) external;
    function withdraw(address _forUser, uint256[] memory _wnftTokenIds) external;

    function totalSupply() external view returns (uint256);
    function exists(uint256 _tokenId) external view returns (bool);

    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) external;
}

interface IWrappedNFTFactory {
    event WrappedNFTDeployed(IERC721Metadata nft, IWrappedNFT wnft);
    event WNFTOwnerChanged(address wnftOwner);
    event WNFTAdminChanged(address wnftAdmin);
    event WNFTRoyaltyInfoChanged(address _wnftRoyaltyReceiver, uint96 _wnftRoyaltyFeeNumerator);

    function wnftOwner() external view returns (address);
    function wnftAdmin() external view returns (address);
    function wnftRoyaltyReceiver() external view returns (address);
    function wnftRoyaltyFeeNumerator() external view returns (uint96);

    function deployWrappedNFT(IERC721Metadata nft) external returns (IWrappedNFT);
    function wnfts(IERC721Metadata nft) external view returns (IWrappedNFT);
    function wnftsNumber() external view returns (uint);
}