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

    function nftContract() external view returns (IERC721Metadata);
    function deposit(address _forUser, uint256[] memory _tokenIds) external;
    function withdraw(address _forUser, uint256[] memory _wnftTokenIds) external;
}

interface INFTMasterChef {
    event Deposit(address indexed user, uint256 indexed pid, uint256[] tokenIds);
    event Withdraw(address indexed user, uint256 indexed pid, uint256[] wnfTokenIds);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256[] wnfTokenIds);
    event Harvest(address indexed user, uint256 indexed pid, uint256 mining, uint256 dividend);
    event EmergencyStop(address indexed user, address to);
    event Add(IWrappedNFT wnftContract, uint256 rewardForEachBlock, uint256 rewardPerNFTForEachBlock, uint256 startBlock, uint256 endBlock, 
        uint256 depositFee, uint256 rewardDevRatio, bool rewardVeToken, IERC20 dividendToken, bool _withTokenTransfer, bool withUpdate);
    event SetPoolInfo(uint256 pid, uint256 rewardForEachBlock, uint256 rewardPerNFTForEachBlock, uint256 startBlock, uint256 endBlock, bool withUpdate);
    event ClosePool(uint256 pid, address payable to);
    event SetPoolDividendToken(uint256 pid, IERC20 dividendToken);
    event UpdateDevAddress(address payable devAddress);
    event UpdateBuyAddress(address payable buyAddress);
    event AddRewardForPool(uint256 pid, uint256 addTokenPerPool, uint256 addTokenPerBlock, bool withTokenTransfer);
    event AddDividendRewardForPool(uint256 _pid, uint256 _addDividend);
    event SetPoolDepositFee(uint256 pid, uint256 depositFee);
    event SetLockBlockNumber(uint256 lockBlockNumber);

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
        
    }

    function poolInfo(uint256 _pid) external view returns (PoolInfo memory);
    // function poolInfo(uint256 _pid) external returns (IWrappedNFT _wnftContract, uint256 _rewardForEachBlock, 
    //     uint256 _rewardPerNFTForEachBlock, uint256 _startBlock, uint256 _endBlock, uint256 _amount, 
    //     uint256 _lastRewardBlock, uint256 _accTokenPerShare, uint256 _depositFee, uint256 _rewardDevRatio, 
    //     bool _rewardVeToken, IERC20 _dividendToken, uint256 _accDividendPerShare);
    function poolNFTInfo(uint256 _pid, uint256 _nftTokenId) external view returns (NFTInfo memory);

    function pending(uint256 _pid, uint256[] memory _wnftTokenIds) external view returns (uint256 mining, uint256 dividend);
    function deposit(uint256 _pid, uint256[] memory _tokenIds) external payable;
    function withdraw(uint256 _pid, uint256[] memory _wnftTokenIds) external;
    function harvest(uint256 _pid, address _to, uint256[] memory _wnftTokenIds) external returns (uint256 mining, uint256 dividend);
}

  
contract NFTInstrument {

    function getNFTMasterChefPoolInfo(address _nftMasterchef, uint256 _pid, address _owner, uint256 _maxTokenId) public view
     returns (INFTMasterChef.PoolInfo memory poolInfo, uint256 mining, uint256 dividend, uint256 nftQuantity, uint256 wnftQuantity) 
     {
       require(_nftMasterchef != address(0),"NFTInstrument: nftMasterchef address is the zero address");
       INFTMasterChef nftMasterchef = INFTMasterChef(_nftMasterchef); 
       poolInfo = nftMasterchef.poolInfo(_pid);

       if (_owner != address(0)) {
         uint256[] memory wnftTokenIds = ownTokens(poolInfo.wnftContract, _owner, _maxTokenId);
         require(wnftTokenIds.length > 0, "NFTInstrument:owner has no wnftToken");
         (mining,  dividend) = nftMasterchef.pending(_pid, wnftTokenIds);

         IWrappedNFT wnftContract = poolInfo.wnftContract;
         nftQuantity = wnftContract.nftContract().balanceOf(_owner);

         wnftQuantity = IERC721(poolInfo.wnftContract).balanceOf(_owner);
       }

    }
    
    function ownTokens(IWrappedNFT _wnftContract, address _owner, uint256 _quantity) public view returns (uint256[] memory totalTokens) {
         require(address(_wnftContract) != address(0) && _owner != address(0) && _quantity > 0,"NFTInstrument: wnftContract address or owner is the zero address");
        //  uint256 maxIndex;
        //  for (uint256 i = 0; i < _quantity; i++) {
        //        address tokenOwner = _wnftContract.ownerOf(i);
        //       if (tokenOwner == _owner) {
        //          maxIndex++;
        //       }
        //   }
        //   require(maxIndex > 0, "NFTInstrument:owner has no wnftToken");
          uint256 index;
          for (uint256 i = 0; i < _quantity; i++) {
               address tokenOwner = IWrappedNFT(_wnftContract).ownerOf(i);
              if (tokenOwner == _owner) {
                  totalTokens[index] = i;
                  index++;
              }
          }
          return totalTokens;
    }
    
}