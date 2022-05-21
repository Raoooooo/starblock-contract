// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IWrappedNFT is IERC721Metadata {
    event SetAdmin(address _admin);
    event Deposit(address indexed _forUser, uint256[] _tokenIds);
    event Withdraw(address indexed _forUser, uint256[] _wnftTokenIds);

    function nft() external view returns (IERC721Metadata);
    function deposit(address _forUser, uint256[] memory _tokenIds) external;
    function withdraw(address _forUser, uint256[] memory _wnftTokenIds) external;
}

interface INFTMasterChef {
    // Info of each user.
    struct NFTInfo {
        bool deposited;     // If the NFT is deposited.
        uint256 rewardDebt; // Reward debt.

        uint256 dividendDebt; // Reward debt.
    }

    // Info of each pool.
    struct PoolInfo {
        IWrappedNFT wnftContract;// Address of LP token contract, zero represents mainnet coin pool.

        uint256 rewardForEachBlock;    //Reward for each block
        uint256 rewardPerNFTForEachBlock;    //Reward for each block

        uint256 startBlock; // Reward start block.
        uint256 endBlock;  // Reward end block.

        uint256 amount;     // How many LP tokens the pool has.
        
        uint256 lastRewardBlock;  // Last block number that SUSHIs distribution occurs.
        uint256 accTokenPerShare; // Accumulated tokens per share, times 1e12.

        uint256 depositFee;// ETH charged when user deposit.
        uint256 rewardDevRatio;// if reward dev when reward the farmers.
        bool rewardVeToken;// if the reward is VeToken

        IERC20 dividendToken;
        uint256 accDividendPerShare;

        // mapping (uint256 => NFTInfo) nfts;
    }
    
    function poolInfo(uint256 _pid) external view returns (PoolInfo memory);
    
    function poolNFTInfo(uint256 _pid, uint256 _nftTokenId) external view returns (NFTInfo memory);

    function pending(uint256 _pid, uint256[] memory _wnftTokenIds) external view returns (uint256 mining, uint256 dividend);
    function deposit(uint256 _pid, uint256[] memory _tokenIds) external payable;
    function withdraw(uint256 _pid, uint256[] memory _wnftTokenIds) external;
    function harvest(uint256 _pid, address _to, uint256[] memory _wnftTokenIds) external returns (uint256 mining, uint256 dividend);
}
  
contract NFTUtils {
    function getNFTMasterChefInfos(INFTMasterChef _nftMasterchef, uint256 _pid, address _owner, uint256 _maxTokenId) public view
     returns (INFTMasterChef.PoolInfo memory poolInfo, uint256 mining, uint256 dividend, uint256 nftQuantity, uint256 wnftQuantity) 
     {
       require(address(_nftMasterchef) != address(0),"NFTUtils: nftMasterchef address is the zero address");
       INFTMasterChef nftMasterchef = _nftMasterchef; 
       poolInfo = nftMasterchef.poolInfo(_pid);

       if (_owner != address(0)) {
         uint256[] memory wnftTokenIds = ownTokens(poolInfo.wnftContract, _owner, _maxTokenId);
         require(wnftTokenIds.length > 0, "NFTInstrument:owner has no wnftToken");
         (mining,  dividend) = nftMasterchef.pending(_pid, wnftTokenIds);

         IWrappedNFT wnftContract = poolInfo.wnftContract;
         nftQuantity = wnftContract.nft().balanceOf(_owner);

         wnftQuantity = poolInfo.wnftContract.balanceOf(_owner);
       }
    }
    
    function ownTokens(IERC721 _nftContract, address _owner, uint256 _maxTokenId) public view returns (uint256[] memory totalTokens) {
         require(address(_nftContract) != address(0) && _owner != address(0) && _maxTokenId > 0,"NFTUtils: nftContract address or owner is the zero address");
        //  uint256 maxIndex;
        //  for (uint256 i = 0; i < _quantity; i++) {
        //        address tokenOwner = _nftContract.ownerOf(i);
        //       if (tokenOwner == _owner) {
        //          maxIndex++;
        //       }
        //   }
        //   require(maxIndex > 0, "NFTUtils: owner has no wnftToken");
          uint256 index;
          for (uint256 i = 0; i < _maxTokenId; i++) {
               address tokenOwner = _nftContract.ownerOf(i);
              if (tokenOwner == _owner) {
                  totalTokens[index ++] = i;
              }
          }
    }
}
