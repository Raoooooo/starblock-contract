// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC2981Mutable is IERC165, IERC2981 {
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) external;
    function deleteDefaultRoyalty() external;
}

interface IBaseWrappedNFT is IERC165, IERC2981Mutable, IERC721Receiver, IERC721, IERC721Metadata {
    event DelegatorChanged(address _delegator);
    event Deposit(address indexed _forUser, uint256[] _tokenIds);
    event Withdraw(address indexed _forUser, uint256[] _wnftTokenIds);

    function nft() external view returns (IERC721Metadata);
    function factory() external view returns (IWrappedNFTFactory);

    function deposit(address _forUser, uint256[] memory _tokenIds) external;
    function withdraw(address _forUser, uint256[] memory _wnftTokenIds) external;

    function exists(uint256 _tokenId) external view returns (bool);
    
    function delegator() external view returns (address);
    function setDelegator(address _delegator) external;
    
    function isEnumerable() external view returns (bool);
}

interface IWrappedNFT is IBaseWrappedNFT {
    function totalSupply() external view returns (uint256);
}

interface IWrappedNFTEnumerable is IWrappedNFT, IERC721Enumerable {
    function totalSupply() external view override(IWrappedNFT, IERC721Enumerable) returns (uint256);
}

interface IWrappedNFTFactory {
    event WrappedNFTDeployed(IERC721Metadata _nft, IWrappedNFT _wnft, bool _isEnumerable);
    event WNFTDelegatorChanged(address _wnftDelegator);

    function wnftDelegator() external view returns (address);

    function deployWrappedNFT(IERC721Metadata _nft, bool _isEnumerable) external returns (IWrappedNFT);
    function wnfts(IERC721Metadata _nft) external view returns (IWrappedNFT);
    function wnftsNumber() external view returns (uint);
}

contract NFTUtils {
    function ownedNFTTokenIds(IERC721 _nft, address _owner, uint256 _maxTokenId) public view returns (uint256[] memory _totalTokenIds) {
        if(address(_nft) == address(0) || _owner == address(0)){
            return _totalTokenIds;
        }
        if (_nft.supportsInterface(type(IERC721Enumerable).interfaceId)) {
            IERC721Enumerable nftEnumerable = IERC721Enumerable(address(_nft));
            _totalTokenIds = ownedNFTEnumerableTokenIds(nftEnumerable, _owner);
        }else{
            _totalTokenIds = ownedNFTNotEnumerableTokenIds(_nft, _owner, _maxTokenId);
        }
    }
    
    function ownedNFTEnumerableTokenIds(IERC721Enumerable _nftEnumerable, address _owner) public view returns (uint256[] memory _totalTokenIds) {
        if(address(_nftEnumerable) == address(0) || _owner == address(0)){
            return _totalTokenIds;
        }
        uint256 balance = _nftEnumerable.balanceOf(_owner);
        if (balance > 0) {
            _totalTokenIds = new uint256[](balance);
            for (uint256 i = 0; i < balance; i++) {
                uint256 tokenId = _nftEnumerable.tokenOfOwnerByIndex(_owner, i);
                _totalTokenIds[i] = tokenId;
            }
        }
    }

    function ownedNFTNotEnumerableTokenIds(IERC721 _nft, address _owner, uint256 _maxTokenId) public view returns (uint256[] memory _totalTokenIds) {
        if(address(_nft) == address(0) || _owner == address(0)){
            return _totalTokenIds;
        }
        uint256 maxIndex;
        for (uint256 tokenId  = 0; tokenId <= _maxTokenId; tokenId ++) {
            if (_tokenIdExists(_nft, tokenId)) {
                address tokenOwner = _nft.ownerOf(tokenId);
                if (tokenOwner == _owner) {
                    maxIndex ++;
                }
            }
        }
        if(maxIndex > 0){
            _totalTokenIds = new uint256[](maxIndex);
            uint256 index;
            for (uint256 tokenId = 0; tokenId <= _maxTokenId; tokenId ++) {
                if (_tokenIdExists(_nft, tokenId)) {
                    address tokenOwner = _nft.ownerOf(tokenId);
                    if (tokenOwner == _owner) {
                        _totalTokenIds[index] = tokenId;
                        index ++;
                    }
                }
            }
        }
    }

    function _tokenIdExists(IERC721 _nft, uint256 _tokenId) internal view returns (bool){
        if(_nft.supportsInterface(type(IWrappedNFT).interfaceId)){
            IWrappedNFT wnft = IWrappedNFT(address(_nft));
            return wnft.exists(_tokenId);
        }
        return true;
    }
}
