// SPDX-License-Identifier: MIT
// StarBlock DAO Contracts

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./wnft_interfaces.sol";

interface INFTMasterChef {
    // Info of each user.
    struct NFTInfo {
        bool deposited;     // If the NFT is deposited.
        uint256 rewardDebt; // Reward debt.

        uint256 dividendDebt; // Reward debt.
    }

    //Reward info 
    struct RewardInfo {
        uint256 rewardBlock;//reduce every block from start block number to (reduceRatio / RATIO_BASE) * last reward
        // uint256 rewardChangeRatio;//ratio afer reduceBlockNumber
        uint256 rewardForEachBlock;    //Reward for each block
        uint256 rewardPerNFTForEachBlock;    //Reward for each block
    }

    // Info of each pool.
    struct PoolInfo {
        IWrappedNFT wnft;// Address of LP token contract, zero represents mainnet coin pool.

        uint256 startBlock; // Reward start block.

        uint256 currentRewardIndex;// the current reward phase index for poolsRewardInfos
        uint256 currentRewardEndBlock;  // Reward end block.

        uint256 amount;     // How many LP tokens the pool has.
        
        uint256 lastRewardBlock;  // Last block number that SUSHIs distribution occurs.
        uint256 accTokenPerShare; // Accumulated tokens per share, times 1e12.
        
        IERC20 dividendToken;
        uint256 accDividendPerShare;

        uint256 depositFee;// ETH charged when user deposit.
    }
    
    function poolLength() external view returns (uint256);
    function poolRewardLength(uint256 _pid) external view returns (uint256);

    function poolInfos(uint256 _pid) external view returns (PoolInfo memory poolInfo);
    function poolsRewardInfos(uint256 _pid, uint256 _rewardInfoId) external view returns (RewardInfo memory rewardInfo);
    function poolNFTInfos(uint256 _pid, uint256 _nftTokenId) external view returns (bool _deposited, uint256 _rewardDebt, uint256 _dividendDebt);

    function getPoolCurrentReward(uint256 _pid) external view returns (RewardInfo memory _rewardInfo, uint256 _currentRewardIndex);
    function getPoolEndBlock(uint256 _pid) external view returns (uint256 _poolEndBlock);
    function isPoolEnd(uint256 _pid) external view returns (bool);

    function pending(uint256 _pid, uint256[] memory _wnftTokenIds) external view returns (uint256 _mining, uint256 _dividend);
    function deposit(uint256 _pid, uint256[] memory _tokenIds) external payable;
    function withdraw(uint256 _pid, uint256[] memory _wnftTokenIds) external;
    function withdrawWithoutHarvest(uint256 _pid, uint256[] memory _wnftTokenIds) external;
    function harvest(uint256 _pid, address _forUser, uint256[] memory _wnftTokenIds) external returns (uint256 _mining, uint256 _dividend);
}

// harvest strategy contract, for havesting perssion
interface IHarvestStrategy {
    function canHarvest(uint256 _pid, address _to, uint256[] memory _wnfTokenIds) external view returns (bool);
}

contract HarvestStrategyPass is IHarvestStrategy, Ownable, ReentrancyGuard {
    INFTMasterChef public immutable nftMasterChef;
    
    //the nfts that do not need any permission
    IERC721Metadata[] public whitelistNFTs;
    //for all pools hold can harvest
    IERC721Metadata[] public commonPasses;
    mapping (uint256 => IERC721Metadata[]) public poolsPasses;

    constructor(
        INFTMasterChef _nftMasterChef
    )  {
        require(address(_nftMasterChef) != address(0), 
            "HarvestStrategy: invalid parameters!");
        nftMasterChef = _nftMasterChef;
    }
    
    function whitelistNFTsLength() external view returns (uint256) {
        return whitelistNFTs.length;
    }

    function commonPassesLength() external view returns (uint256) {
        return commonPasses.length;
    }

    function poolPassesLength(uint256 _pid) external view returns (uint256) {
        return poolsPasses[_pid].length;
    }
    
    function addWhitelistNFTs(IERC721Metadata[] memory _nfts) external onlyOwner nonReentrant {
        _addToArray(_nfts, whitelistNFTs);
    }

    function addCommonPasses(IERC721Metadata[] memory _passes) external onlyOwner nonReentrant {
        _addToArray(_passes, commonPasses);
    }

    // add the _passes1 element to _passes2
    function _addToArray(IERC721Metadata[] memory _passes1, IERC721Metadata[] storage _passes2) internal {
        for(uint256 index1 = 0; index1 < _passes1.length; index1 ++){
            IERC721Metadata pass1 = _passes1[index1];
            bool exist = false;
            for(uint256 index2 = 0; index2 < _passes2.length; index2 ++){
                IERC721Metadata pass2 = _passes2[index2];
                if(pass1 == pass2){
                    exist = true;
                    break;
                }
            }
            if(!exist){
                _passes2.push(pass1);
            }
        }
    }

    function _burn(IERC721Metadata[] storage _array, uint256 _index) internal {
        require(_index < _array.length);
        _array[_index] = _array[_array.length - 1];
        _array.pop();
    }
    
    function removeWhitelistNFTs(IERC721Metadata[] memory _nfts) external onlyOwner nonReentrant {
        _removeFromArray(_nfts, whitelistNFTs);
    }

    function removeCommonPasses(IERC721Metadata[] memory _passes) external onlyOwner nonReentrant {
        _removeFromArray(_passes, commonPasses);
    }

    // remove the _passes1 element from _passes2
    function _removeFromArray(IERC721Metadata[] memory _passes1, IERC721Metadata[] storage _passes2) internal {
        for(uint256 index1 = 0; index1 < _passes1.length; index1 ++){
            IERC721Metadata pass1 = _passes1[index1];
            uint256 removeIndex;
            bool exist = false;
            for(uint256 index2 = 0; index2 < _passes2.length; index2 ++){
                IERC721Metadata pass2 = _passes2[index2];
                if(pass1 == pass2){
                    removeIndex = index2;
                    exist = true;
                    break;
                }
            }
            if(exist){
                _burn(_passes2, removeIndex);
            }
        }
    }

    function addPassesForPool(uint256 _pid, IERC721Metadata[] memory _passes) external onlyOwner nonReentrant {
        INFTMasterChef.PoolInfo memory pool =  nftMasterChef.poolInfos(_pid);
        require(pool.currentRewardEndBlock > 0, "NFTMasterChef: invalid pid!");

        IERC721Metadata[] storage poolPasses = poolsPasses[_pid];
        _addToArray(_passes, poolPasses);
    }
    
    function removePassesForPool(uint256 _pid, IERC721Metadata[] memory _passes) external onlyOwner nonReentrant {
        INFTMasterChef.PoolInfo memory pool =  nftMasterChef.poolInfos(_pid);
        require(pool.currentRewardEndBlock > 0, "NFTMasterChef: invalid pid!");

        IERC721Metadata[] storage poolPasses = poolsPasses[_pid];
        _removeFromArray(_passes, poolPasses);
    }

    function canHarvest(uint256 _pid, address _to, uint256[] memory _wnftTokenIds) external view returns (bool) {
        INFTMasterChef.PoolInfo memory pool =  nftMasterChef.poolInfos(_pid);
        if(pool.currentRewardEndBlock == 0){
            return false;
        }

        for(uint256 index = 0; index < whitelistNFTs.length; index ++){
            IERC721Metadata whitelistNFT = whitelistNFTs[index];
            if(address(whitelistNFT) == address(pool.wnft) 
                || address(whitelistNFT) == address(pool.wnft.nft())){
                return true;
            }
        }
        
        if(_own(_to, commonPasses)){
        	return true;
        }

        IERC721Metadata[] storage poolPasses = poolsPasses[_pid];
        if(commonPasses.length == 0 && poolPasses.length == 0){
            return true;
        }
        if(_own(_to, poolPasses)){
        	return true;
        }
        return false;
    }
    
    function _own(address _to, IERC721Metadata[] storage _array) internal view returns (bool) {        
        for(uint256 index = 0; index < _array.length; index ++){
            IERC721Metadata pass = _array[index];
            if(address(pass) != address(0) && pass.balanceOf(_to) > 0){
                return true;
            }
        }
        return false;
    }
}
