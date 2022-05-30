// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./HarvestStrategy.sol";
import "./wnft_interfaces.sol";

contract NFTUtils { 

    function getNFTMasterChefInfos(INFTMasterChef _nftMasterchef, uint256 _pid, address _owner, uint256 _maxTokenId) public view
     returns (INFTMasterChef.PoolInfo memory poolInfo, uint256 rewardForEachBlock, uint256 rewardPerNFTForEachBlock, uint256 endBlock, uint256 mining, uint256 dividend, uint256 nftQuantity, uint256 wnftQuantity) 
     {
       require(address(_nftMasterchef) != address(0),"NFTUtils: nftMasterchef address is the zero address");
       INFTMasterChef nftMasterchef = _nftMasterchef; 
       poolInfo = nftMasterchef.poolInfos(_pid);
        INFTMasterChef.RewardInfo memory rewardInfo = nftMasterchef.poolsRewardInfos(_pid, poolInfo.currentRewardIndex);
        rewardForEachBlock = rewardInfo.rewardForEachBlock;
        rewardPerNFTForEachBlock = rewardInfo.rewardPerNFTForEachBlock;
        endBlock = nftMasterchef.getPoolEndBlock(_pid);
     
       if (_owner != address(0)) {
         uint256[] memory wnftTokenIds = ownedWNFTTokens(poolInfo.wnft, _owner, _maxTokenId);
         if (wnftTokenIds.length > 0) {
             (mining,  dividend) = nftMasterchef.pending(_pid, wnftTokenIds);
         }
    
         IWrappedNFT wnft = poolInfo.wnft;
         nftQuantity = wnft.nft().balanceOf(_owner);

         wnftQuantity = poolInfo.wnft.balanceOf(_owner);
       }
    }
    

    function ownedWNFTTokens(IWrappedNFT _wnftContract, address _owner, uint256 _maxTokenId) public view returns (uint256[] memory totalTokens) {
         require(address(_wnftContract) != address(0) && _owner != address(0) && _maxTokenId >= 0, "NFTUtils: wnftContract address or owner is the zero address");
         if (_wnftContract.isEnumerable()) {
             IWrappedNFTEnumerable wnftEnumerable = IWrappedNFTEnumerable(address(_wnftContract));
             totalTokens = ownedTokens(wnftEnumerable,_owner);
         }else {
                uint256 maxIndex;
                for (uint256 i  = 0; i <= _maxTokenId; i++) {
                    if (_wnftContract.exists(i)) {
                        address tokenOwner = _wnftContract.ownerOf(i);
                        if (tokenOwner == _owner) {
                            maxIndex++;
                        }
                    }
                }
                require(maxIndex > 0, "NFTUtils: owner has no token");
                totalTokens = new uint256[](maxIndex);
                uint256 index;
                for (uint256 i = 0; i <= _maxTokenId; i++) {
                    if (_wnftContract.exists(i)) {
                        address tokenOwner = _wnftContract.ownerOf(i);
                        if (tokenOwner == _owner) {
                            totalTokens[index] = i;
                            index++;
                        }
                    }
             }
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

}
