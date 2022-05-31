// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./HarvestStrategy.sol";
import "./wnft_interfaces.sol";


struct UserInfo {
    uint256 mining;
    uint256 dividend;
    uint256 nftQuantity;
    uint256 wnftQuantity;
    bool isNFTApproved;
    bool isWNFTApproved;
}

contract NFTUtils { 

    function getNFTMasterChefInfos(INFTMasterChef _nftMasterchef, uint256 _pid, address _owner, uint256 _maxTokenId) public view
     returns (INFTMasterChef.PoolInfo memory poolInfo, INFTMasterChef.RewardInfo memory rewardInfo, UserInfo memory userInfo, uint256 currentRewardIndex, 
        uint256 endBlock, address nft) 
     {
        require(address(_nftMasterchef) != address(0),"NFTUtils: nftMasterchef address is the zero address");
        INFTMasterChef nftMasterchef = _nftMasterchef; 
        poolInfo = nftMasterchef.poolInfos(_pid);
        (rewardInfo, currentRewardIndex)  = nftMasterchef.getPoolCurrentReward(_pid);
        endBlock = nftMasterchef.getPoolEndBlock(_pid);
     
       if (_owner != address(0)) {
         uint256[] memory wnftTokenIds = ownedNFTTokens(poolInfo.wnft, _owner, _maxTokenId);
         userInfo = UserInfo({mining:0, dividend:0, nftQuantity:0, wnftQuantity:0, isNFTApproved:false, isWNFTApproved:false});
         if (wnftTokenIds.length > 0) {
             (userInfo.mining, userInfo.dividend) = nftMasterchef.pending(_pid, wnftTokenIds);
         }
    
         IWrappedNFT wnft = poolInfo.wnft;
         userInfo.nftQuantity = wnft.nft().balanceOf(_owner);
         userInfo.wnftQuantity = wnft.balanceOf(_owner);
         userInfo.isNFTApproved = wnft.nft().isApprovedForAll(_owner, address(wnft));
         userInfo.isWNFTApproved = wnft.isApprovedForAll(_owner, address(_nftMasterchef));
         nft = address(wnft.nft());
       }
    }
    

    function ownedTokens(IERC721Enumerable _nftContract, address _owner) public view returns (uint256[] memory totalTokens) {
         require(address(_nftContract) != address(0) && _owner != address(0), "NFTUtils: nftContract address or owner is the zero address");
         uint256 balance = _nftContract.balanceOf(_owner);
         if (balance > 0) {
            totalTokens = new uint256[](balance);
            for (uint256 i = 0; i < balance; i++) {
                uint256 tokenId = _nftContract.tokenOfOwnerByIndex(_owner, i);
                totalTokens[i] = tokenId;
            }
         }
    }

    function ownedNFTTokens(IERC721Metadata _nft, address _owner, uint256 _maxTokenId) public view returns (uint256[] memory totalTokens) {
         require(address(_nft) != address(0) && _owner != address(0) && _maxTokenId >= 0, "NFTUtils: wnftContract address or owner is the zero address");
        //  if (_nft.isEnumerable()) {
        if (_nft.supportsInterface(type(IERC721Enumerable).interfaceId)) {
            IERC721Enumerable nftEnumerable = IERC721Enumerable(address(_nft));
            // totalTokens = ownedTokens(nftEnumerable, _owner);
            uint256 balance = nftEnumerable.balanceOf(_owner);
            if (balance > 0) {
                totalTokens = new uint256[](balance);
                for (uint256 i = 0; i < balance; i++) {
                    uint256 tokenId = nftEnumerable.tokenOfOwnerByIndex(_owner, i);
                    totalTokens[i] = tokenId;
                }
            }
         }else if(_nft.supportsInterface(type(IWrappedNFT).interfaceId)){
             IWrappedNFT wnft = IWrappedNFT(address(_nft));
                uint256 maxIndex;
                for (uint256 i  = 0; i <= _maxTokenId; i++) {
                    if (wnft.exists(i)) {
                        address tokenOwner = wnft.ownerOf(i);
                        if (tokenOwner == _owner) {
                            maxIndex ++;
                        }
                    }
                }
                if(maxIndex > 0){
                    totalTokens = new uint256[](maxIndex);
                    uint256 index;
                    for (uint256 i = 0; i <= _maxTokenId; i++) {
                        if (wnft.exists(i)) {
                            address tokenOwner = wnft.ownerOf(i);
                            if (tokenOwner == _owner) {
                                totalTokens[index] = i;
                                index ++;
                            }
                        }
                    }
                }
         }else{
                uint256 maxIndex;
                for (uint256 i  = 0; i <= _maxTokenId; i++) {
                    address tokenOwner = _nft.ownerOf(i);
                    if (tokenOwner == _owner) {
                        maxIndex ++;
                    }
                }
                if(maxIndex > 0){
                    totalTokens = new uint256[](maxIndex);
                    uint256 index;
                    for (uint256 i = 0; i <= _maxTokenId; i++) {
                        address tokenOwner = _nft.ownerOf(i);
                        if (tokenOwner == _owner) {
                            totalTokens[index] = i;
                            index ++;
                        }
                    }
                }
         }
    }

}
