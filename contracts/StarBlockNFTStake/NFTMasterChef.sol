// SPDX-License-Identifier: MIT
// StarBlock Contracts

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

import "./wnft_interfaces.sol";
import "./ArrayUtils.sol";

interface VeToken is IERC20 {
    function lock(address _forUser, uint256 _amount, uint256 _lockTokenBlockNumber) external returns (uint256 _id);
    function minimumLockAmount() external returns (uint256 min);
}

interface INFTMasterChef {
    event AddPoolInfo(IERC721Metadata nftContract, IWrappedNFT wnftContract, uint256 rewardForEachBlock, uint256 rewardPerNFTForEachBlock, uint256 startBlock, uint256 endBlock, 
        uint256 depositFee, uint256 rewardDevRatio, bool rewardVeToken, IERC20 _dividendToken, bool withTokenTransfer, bool withUpdate);
    event SetPoolInfo(uint256 pid, uint256 rewardForEachBlock, uint256 rewardPerNFTForEachBlock, uint256 startBlock, uint256 endBlock, bool withUpdate);
    event SetPoolDepositFee(uint256 pid, uint256 depositFee);
    event SetVeTokenAndLockBlockNumber(VeToken veToken, uint256 lockBlockNumber);
    event SetPoolDividendToken(uint256 pid, IERC20 dividendToken);
    event AddTokenRewardForPool(uint256 pid, uint256 addTokenPerPool, uint256 addTokenPerBlock, bool withTokenTransfer);
    event AddDividendForPool(uint256 _pid, uint256 _addDividend);

    event UpdateDevAddress(address payable devAddress);
    event EmergencyStop(address indexed user, address to);
    event ClosePool(uint256 pid, address payable to);

    event Deposit(address indexed user, uint256 indexed pid, uint256[] tokenIds);
    event Withdraw(address indexed user, uint256 indexed pid, uint256[] wnfTokenIds);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256[] wnfTokenIds);
    event Harvest(address indexed user, uint256 indexed pid, uint256 mining, uint256 dividend);

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
    
    function poolInfos(uint256 _pid) external view returns (IWrappedNFT wnftContract, uint256 rewardForEachBlock, uint256 rewardPerNFTForEachBlock, 
                uint256 startBlock, uint256 endBlock, uint256 amount, uint256 lastRewardBlock, uint256 accTokenPerShare, uint256 depositFee, 
                uint256 rewardDevRatio, bool rewardVeToken, IERC20 dividendToken, uint256 accDividendPerShare);
    function poolNFTInfos(uint256 _pid, uint256 _nftTokenId) external view returns (bool deposited, uint256 rewardDebt, uint256 dividendDebt);

    function pending(uint256 _pid, uint256[] memory _wnftTokenIds) external view returns (uint256 mining, uint256 dividend);
    function deposit(uint256 _pid, uint256[] memory _tokenIds) external payable;
    function withdraw(uint256 _pid, uint256[] memory _wnftTokenIds) external;
    function harvest(uint256 _pid, address _to, uint256[] memory _wnftTokenIds) external returns (uint256 mining, uint256 dividend);
}

// MasterChef is the master of Token. He can make Token and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once SUSHI is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.

//TODO 主要是支持抵押NFT挖矿和分红两个逻辑，分红一开始也要支持好。
contract NFTMasterChef is INFTMasterChef, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using ArrayUtils for uint256[];

    uint256 private constant ACC_TOKEN_PRECISION = 1e12;
    uint256 public constant RATIO_BASE = 1000;

    IWrappedNFTFactory public wnftFactory;// can not changed

    // The SUSHI TOKEN!
    IERC20 public token;
    VeToken public veToken;

    // Dev address.
    address payable public devAddress;
    uint256 public lockBlockNumber = 6500 * 30;

    // Info of each pool.
    PoolInfo[] public poolInfos;
    
    mapping (uint256 => NFTInfo)[] public poolNFTInfos;// the nftInfo for pool
    
    // Info of each user that stakes LP tokens.
    // mapping (uint256 => mapping (address => UserInfo)) public userInfo;

    modifier validatePoolByPid(uint256 _pid) {
        require(_pid < poolInfos.length, "Pool does not exist");
        _;
    }

    constructor(
        IWrappedNFTFactory _wnftFactory,
        IERC20 _token,
        address payable _devAddress
    )  {
        require(address(_wnftFactory) != address(0) && address(_token) != address(0) 
            && address(_devAddress) != address(0), "WrappedNFT: invalid parameters!");
        wnftFactory = _wnftFactory;
        token = _token;
        devAddress = _devAddress;
    }

    function poolLength() external view returns (uint256) {
        return poolInfos.length;
    }

    function setVeTokenAndLockBlockNumber(VeToken _veToken, uint256 _lockBlockNumber) external onlyOwner nonReentrant {
        require(address(veToken) == address(0) && address(_veToken) != address(0), "WrappedNFT: veToken can not be modified!");
        veToken = _veToken;
        lockBlockNumber = _lockBlockNumber;
        emit SetVeTokenAndLockBlockNumber(_veToken, _lockBlockNumber);
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // Zero lpToken represents mainnet coin pool.
    function addPoolInfo(IERC721Metadata _nftContract, uint256 _rewardForEachBlock, uint256 _rewardPerNFTForEachBlock, 
        uint256 _startBlock, uint256 _endBlock, uint256 _depositFee,
        uint256 _rewardDevRatio, bool _rewardVeToken, IERC20 _dividendToken,
        bool _withTokenTransfer, bool _withUpdate) external onlyOwner nonReentrant {
        //require(_lpToken != IERC20(0), "lpToken can not be zero!");
        require(_startBlock < _endBlock, "NFTMasterChef: start block must less than end block!");
        require(_rewardDevRatio < RATIO_BASE, "NFTMasterChef: _rewardDevRatio must less than RATIO_BASE!");
        //allow pool with dividend and without mining, or must have mining. Mining can only have either _rewardForEachBlock or _rewardPerNFTForEachBlock set.
        require((address(_dividendToken) != address(0) && (_rewardForEachBlock == 0 && _rewardPerNFTForEachBlock == 0)) || 
                ((_rewardForEachBlock == 0 && _rewardPerNFTForEachBlock > 0) || (_rewardForEachBlock > 0 && _rewardPerNFTForEachBlock == 0)), 
                "NFTMasterChef: rewardForEachBlock or rewardPerNFTForEachBlock must be greater than zero!");
        require(!_rewardVeToken || (_rewardVeToken && address(veToken) != address(0)), "NFTMasterChef: _rewardVeToken must setting with veToken!");

        IWrappedNFT wnft = wnftFactory.wnfts(_nftContract);
        require(address(wnft) != address(0) && wnft.nft() == _nftContract && wnft.admin() == address(this), "NFTMasterChef: wrong wnftFactory!");
        
        if (_withUpdate) {
            massUpdatePools();
        }
        PoolInfo storage pool = poolInfos.push();
        pool.wnftContract = wnft;
        pool.rewardForEachBlock = _rewardForEachBlock;
        pool.rewardPerNFTForEachBlock = _rewardPerNFTForEachBlock;
        pool.startBlock = _startBlock;
        pool.endBlock = _endBlock;
        pool.amount = 0;
        pool.lastRewardBlock = block.number > _startBlock ? block.number : _startBlock;
        pool.accTokenPerShare = 0;
        // pool.rewarded = 0;
        pool.depositFee = _depositFee;
        pool.rewardDevRatio = _rewardDevRatio;
        pool.rewardVeToken = _rewardVeToken;

        pool.dividendToken = _dividendToken;
        pool.accDividendPerShare = 0;
        if(_withTokenTransfer && _rewardForEachBlock > 0){
            uint256 amount = (_endBlock - (block.number > _startBlock ? block.number : _startBlock)).mul(_rewardForEachBlock);
            token.safeTransferFrom(msg.sender, address(this), amount);
        }

        poolNFTInfos.push();
        emit AddPoolInfo(_nftContract, wnft, _rewardForEachBlock, _rewardPerNFTForEachBlock, _startBlock, _endBlock, 
            _depositFee, _rewardDevRatio, _rewardVeToken, _dividendToken, _withTokenTransfer, _withUpdate);
    }

    // Update the given pool's pool info. Can only be called by the owner.
    function setPoolInfo(uint256 _pid, uint256 _rewardForEachBlock, uint256 _rewardPerNFTForEachBlock, 
        uint256 _startBlock, uint256 _endBlock, bool _withUpdate) external validatePoolByPid(_pid) onlyOwner nonReentrant {
        require((_rewardForEachBlock == 0 && _rewardPerNFTForEachBlock > 0) || (_rewardForEachBlock > 0 && _rewardPerNFTForEachBlock == 0), 
                "NFTMasterChef: must set reward way!");
        if (_withUpdate) {
            massUpdatePools();
        }
        PoolInfo storage pool = poolInfos[_pid];
        if(pool.startBlock < block.number){
            require(_startBlock == 0, "NFTMasterChef: can not change start block of started pool!");
        }
        require((pool.rewardPerNFTForEachBlock > 0 && _rewardPerNFTForEachBlock > 0) || (_rewardForEachBlock > 0 && pool.rewardForEachBlock > 0), 
                "NFTMasterChef: do not change reward way!");
        if(_startBlock > 0){
            if(_endBlock > 0){
                require(_startBlock < _endBlock, "NFTMasterChef: start block must less than end block!");
            }else{
                require(_startBlock < pool.endBlock, "NFTMasterChef: start block must less than end block!");
            }
            pool.startBlock = _startBlock;
        }
        if(_endBlock > 0){
            if(_startBlock <= 0){
                require(pool.startBlock < _endBlock, "NFTMasterChef: start block must less than end block!");
            }
            pool.endBlock = _endBlock;
        }
        pool.rewardForEachBlock = _rewardForEachBlock;
        pool.rewardPerNFTForEachBlock = _rewardPerNFTForEachBlock;
        emit SetPoolInfo(_pid, _rewardForEachBlock, _rewardPerNFTForEachBlock, _startBlock, _endBlock, _withUpdate);
    }

    // Update the given pool's pool info. Can only be called by the owner.
    function setPoolDividendToken(uint256 _pid, IERC20 _dividendToken) external validatePoolByPid(_pid) onlyOwner nonReentrant {
        PoolInfo storage pool = poolInfos[_pid];
        require(address(pool.dividendToken) == address(0) || pool.accDividendPerShare == 0, "NFTMasterChef: dividendToken can not be modified!");
        pool.dividendToken = _dividendToken;
        emit SetPoolDividendToken(_pid, _dividendToken);
    }

    function setAllPoolDepositFee(uint256 _depositFee) external onlyOwner {
        uint256 length = poolInfos.length;
        for (uint256 pid = 0; pid < length; ++ pid) {
            setPoolDepositFee(pid, _depositFee);
        }
    }

    // Update the given pool's operation fee
    function setPoolDepositFee(uint256 _pid, uint256 _depositFee) public validatePoolByPid(_pid) onlyOwner nonReentrant {
        updatePool(_pid);
        PoolInfo storage pool = poolInfos[_pid];
        pool.depositFee = _depositFee;
        emit SetPoolDepositFee(_pid, _depositFee);
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        if(_to > _from){
            return _to.sub(_from);
        }
        return 0;
    }

    function massUpdatePoolAmounts(uint256 _maxTokenId) external nonReentrant {
        uint256 length = poolInfos.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePoolAmount(pid, _maxTokenId);
        }
    }

    //someone may withdraw or deposit from IWrappedNFT contract directly, so give a way to update those NFTs.
    //for withdraw ones delete from pool.
    function updatePoolAmount(uint256 _pid, uint256 _maxTokenId) public validatePoolByPid(_pid) {
        PoolInfo storage pool = poolInfos[_pid];
        mapping(uint256 => NFTInfo) storage nfts = poolNFTInfos[_pid];
        NFTInfo storage nft;
        uint256 deleteNumber;
        for(uint256 tokenId = 0; tokenId < _maxTokenId; tokenId ++){
            // tokenId = tokenIds[index];
            nft = nfts[tokenId];
            if(nft.deposited == true){
                if(!pool.wnftContract.exists(tokenId)){
                    nft.deposited = false;
                    nft.rewardDebt = 0;
                    nft.dividendDebt = 0;
                    deleteNumber ++;
                }
            }
        }
        if(deleteNumber > 0){
            pool.amount = pool.amount.sub(deleteNumber);
            updatePool(_pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public validatePoolByPid(_pid) {
        //TODO 看能否更新一下amount，因为amount可能会出错，因为有人可能会直接通过WNFT合约来解抵押
        PoolInfo storage pool = poolInfos[_pid];
        if(pool.rewardForEachBlock == 0){//do not update pool when pool.rewardForEachBlock = 0
            return;
        }
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        if (block.number < pool.startBlock){
            return;
        }
        if (pool.lastRewardBlock >= pool.endBlock){
             return;
        }
        if (pool.lastRewardBlock < pool.startBlock) {
            pool.lastRewardBlock = pool.startBlock;
        }
        uint256 multiplier;
        if (block.number > pool.endBlock){
            multiplier = getMultiplier(pool.lastRewardBlock, pool.endBlock);
            pool.lastRewardBlock = pool.endBlock;
        }else{
            multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            pool.lastRewardBlock = block.number;
        }
        if (pool.amount <= 0) {
            return;
        }
        //TODO 测试固定每个NFT每个区块奖励的时候是否正确吧，未必对
        // uint256 rewardForEachBlock = pool.rewardForEachBlock;
        // if(rewardForEachBlock == 0){
        //     rewardForEachBlock = pool.amount * pool.rewardPerNFTForEachBlock;
        // }
        uint256 tokenReward = multiplier.mul(pool.rewardForEachBlock);
        if(tokenReward > 0){
            uint256 poolTokenReward = tokenReward;
            if(pool.rewardDevRatio > 0 && address(devAddress) != address(0)){
                transferToDev(pool, pool.rewardDevRatio, tokenReward);
                poolTokenReward = tokenReward.mul(RATIO_BASE.sub(pool.rewardDevRatio)).div(RATIO_BASE);
            }
            pool.accTokenPerShare = pool.accTokenPerShare.add(poolTokenReward.mul(ACC_TOKEN_PRECISION).div(pool.amount));
        }
    }

    function transferToDev(PoolInfo storage _pool, uint256 _devRatio, uint256 _tokenReward) private returns (uint256 amount){
        if(_devRatio > 0){
            amount = _tokenReward.mul(_devRatio).div(RATIO_BASE);
            if (!_pool.rewardVeToken){
                _safeTransferTokenFromThis(token, devAddress, amount);
            }else{
                _safeLockTokenFromThis(token, devAddress, amount);
            }
            // _pool.rewarded = _pool.rewarded.add(amount);
        }
    }

    // View function to see mining tokens and dividend on frontend.
    function pending(uint256 _pid, uint256[] memory _wnftTokenIds) public view validatePoolByPid(_pid) returns (uint256 mining, uint256 dividend) {
        require(_wnftTokenIds.length > 0, "NFTMasterChef: tokenIds can not be empty!");
        require(!_wnftTokenIds.hasDuplicate(), "NFTMasterChef: tokenIds can not contain duplicate ones!");

        PoolInfo storage pool =  poolInfos[_pid];

        mapping(uint256 => NFTInfo) storage nfts = poolNFTInfos[_pid];

        uint256 accTokenPerShare = pool.accTokenPerShare;
        if(pool.rewardForEachBlock > 0){
            uint256 lastRewardBlock = pool.lastRewardBlock;
            if (lastRewardBlock < pool.startBlock) {
                lastRewardBlock = pool.startBlock;
            }
            if (block.number > lastRewardBlock && block.number >= pool.startBlock && lastRewardBlock < pool.endBlock && pool.amount > 0){
                uint256 multiplier;
                if (block.number > pool.endBlock){
                    multiplier = getMultiplier(lastRewardBlock, pool.endBlock);
                }else{
                    multiplier = getMultiplier(lastRewardBlock, block.number);
                }
                //TODO 测试rewardForEachBlock为0的时候是否正确
                uint256 rewardForEachBlock = pool.rewardForEachBlock;
                if(rewardForEachBlock == 0){
                    rewardForEachBlock = pool.amount.mul(pool.rewardPerNFTForEachBlock);
                }
                accTokenPerShare = accTokenPerShare.add(multiplier.mul(rewardForEachBlock).mul(ACC_TOKEN_PRECISION).div(pool.amount));
            }
        }

        uint256 temp;
        NFTInfo storage nft;
        for(uint256 i = 0; i < _wnftTokenIds.length; i ++){
            uint256 tokenId = _wnftTokenIds[i];
            nft = nfts[tokenId];
            if(nft.deposited == true){
                if(pool.rewardPerNFTForEachBlock > 0){
                    uint256 multiplier = 0;
                    if (block.number > pool.endBlock){
                        multiplier = getMultiplier(pool.startBlock, pool.endBlock);
                    }else{
                        multiplier = getMultiplier(pool.startBlock, block.number);
                    }
                    temp = pool.rewardPerNFTForEachBlock.mul(multiplier);
                }else{
                    temp = accTokenPerShare.div(ACC_TOKEN_PRECISION);
                }
                mining = mining.add(temp.sub(nft.rewardDebt));

                if(address(pool.dividendToken) != address(0) && pool.accDividendPerShare > 0){
                    dividend = dividend.add(pool.accDividendPerShare.div(ACC_TOKEN_PRECISION).sub(nft.dividendDebt));
                }
            }
        }
    }
   
    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfos.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Deposit NFTs to MasterChef for token allocation, do not give user reward.
    function deposit(uint256 _pid, uint256[] memory _tokenIds) external validatePoolByPid(_pid) payable nonReentrant {
        require(_tokenIds.length > 0, "NFTMasterChef: tokenIds can not be empty!");
        require(!_tokenIds.hasDuplicate(), "NFTMasterChef: tokenIds can not contain duplicate ones!");
        updatePool(_pid);
        PoolInfo storage pool = poolInfos[_pid];
        require(block.number <= pool.endBlock, "NFTMasterChef: this pool is end!");
        require(block.number >= pool.startBlock, "NFTMasterChef: this pool is not start!");
        if(pool.depositFee > 0){// charge for fee
            require(msg.value == pool.depositFee, "NFTMasterChef: Fee is not enough or too much!");
            devAddress.transfer(pool.depositFee);
        }
        mapping(uint256 => NFTInfo) storage nfts = poolNFTInfos[_pid];
        uint256 tokenId;
        NFTInfo storage nft;
        uint256 depositNumber;
        for(uint256 i = 0; i < _tokenIds.length; i ++){
            tokenId = _tokenIds[i];
            //ownerOf will return error if tokenId does not exist.
            require(pool.wnftContract.nft().ownerOf(tokenId) == msg.sender, "NFTMasterChef: can not deposit nft not owned!");
            //TODO 第一次tokenId没有，这么写行不行呢？
            nft = nfts[tokenId];
            //If tokenId have reward not harvest, drop it.
            if(nft.deposited == false){
                depositNumber ++;
                nft.deposited = true;
            }
            if(pool.rewardPerNFTForEachBlock > 0){
                uint256 multiplier;
                if (block.number > pool.endBlock){
                    multiplier = getMultiplier(pool.startBlock, pool.endBlock);
                }else{
                    multiplier = getMultiplier(pool.startBlock, block.number);
                }
                nft.rewardDebt = pool.rewardPerNFTForEachBlock.mul(multiplier);
            }else{
                nft.rewardDebt = pool.accTokenPerShare.div(ACC_TOKEN_PRECISION);
            }
            //add dividend info
            // if(address(pool.dividendToken) != address(0) && pool.accDividendPerShare > 0){
                nft.dividendDebt = pool.accDividendPerShare.div(ACC_TOKEN_PRECISION);
            // }
        }
        pool.wnftContract.deposit(msg.sender, _tokenIds);
        pool.amount = pool.amount.add(depositNumber);
        emit Deposit(msg.sender, _pid, _tokenIds);
    }

    // function testDeposit(uint256 _pid, uint256[] memory _tokenIds) external validatePoolByPid(_pid) payable nonReentrant {
    //     PoolInfo storage pool = poolInfos[_pid];
    //     pool.wnftContract.deposit(msg.sender, _tokenIds);
    // }

    // function testWithdraw(uint256 _pid, uint256[] memory _wnftTokenIds) external validatePoolByPid(_pid) nonReentrant {
    //     PoolInfo storage pool = poolInfos[_pid];
    //     pool.wnftContract.withdraw(msg.sender, _wnftTokenIds);
    // }

    // Withdraw NFTs from MasterChef.
    function withdraw(uint256 _pid, uint256[] memory _wnftTokenIds) external validatePoolByPid(_pid) nonReentrant {
        _harvest(_pid, msg.sender, _wnftTokenIds, false);
        _withdrawWithoutHarvest(_pid, _wnftTokenIds);
        emit Withdraw(msg.sender, _pid, _wnftTokenIds);
    }

    function _withdrawWithoutHarvest(uint256 _pid, uint256[] memory _wnftTokenIds) internal validatePoolByPid(_pid) {
        require(_wnftTokenIds.length > 0, "NFTMasterChef: tokenIds can not be empty!");
        require(!_wnftTokenIds.hasDuplicate(), "NFTMasterChef: tokenIds can not contain duplicate ones!");
        // require(block.number >= pool.startBlock,"NFTMasterChef: this pool is not start!");
        // _harvest(_pid, msg.sender, _wnftTokenIds, false);
        PoolInfo storage pool = poolInfos[_pid];
        mapping(uint256 => NFTInfo) storage nfts = poolNFTInfos[_pid];
        uint256 tokenId;
        NFTInfo storage nft;
        uint256 withdrawNumber;
        for(uint256 i = 0; i < _wnftTokenIds.length; i ++){
            tokenId = _wnftTokenIds[i];
            require(pool.wnftContract.ownerOf(tokenId) == msg.sender, "NFTMasterChef: can not withdraw nft now owned!");
            nft = nfts[tokenId];
            if(nft.deposited == true){
                withdrawNumber ++;
                nft.deposited = false;
                nft.rewardDebt = 0;
                nft.dividendDebt = 0;
            }
        }
        pool.wnftContract.withdraw(msg.sender, _wnftTokenIds);
        pool.amount = pool.amount.sub(withdrawNumber);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid, uint256[] memory _wnftTokenIds) external validatePoolByPid(_pid) nonReentrant {
        _withdrawWithoutHarvest(_pid, _wnftTokenIds);
        emit EmergencyWithdraw(msg.sender, _pid, _wnftTokenIds);
    }

    function harvest(uint256 _pid, address _to, uint256[] memory _wnftTokenIds) external validatePoolByPid(_pid) nonReentrant returns (uint256 mining, uint256 dividend) {
       return _harvest(_pid, _to, _wnftTokenIds, false);
    }

    function _harvest(uint256 _pid, address _to, uint256[] memory _wnftTokenIds, bool _isInternal) internal validatePoolByPid(_pid) returns (uint256 mining, uint256 dividend) {
        require(_wnftTokenIds.length > 0, "NFTMasterChef: tokenIds can not be empty!");
        require(!_wnftTokenIds.hasDuplicate(), "NFTMasterChef: tokenIds can not contain duplicate ones!");
        if(_to == address(0)){
            _to = msg.sender;
        }
        // UserInfo storage user = userInfo[_pid][_to];
        updatePool(_pid);
        PoolInfo storage pool =  poolInfos[_pid];
        mapping(uint256 => NFTInfo) storage nfts = poolNFTInfos[_pid];
        uint256 tokenId;
        NFTInfo storage nft;
        uint256 temp = 0;
        for(uint256 i = 0; i < _wnftTokenIds.length; i ++){
            tokenId = _wnftTokenIds[i];
            nft = nfts[tokenId];
            require(pool.wnftContract.ownerOf(tokenId) == _to, "NFTMasterChef: can not harvest nft now owned!");
            if(nft.deposited == true){
                // mining = user.amount.mul(pool.accSushiPerShare).div(ACC_TOKEN_PRECISION).sub(user.rewardDebt);
                if(pool.rewardPerNFTForEachBlock > 0){
                    uint256 multiplier;
                    if (block.number > pool.endBlock){
                        multiplier = getMultiplier(pool.startBlock, pool.endBlock);
                    }else{
                        multiplier = getMultiplier(pool.startBlock, block.number);
                    }
                    temp = pool.rewardPerNFTForEachBlock.mul(multiplier);
                }else{
                    temp = pool.accTokenPerShare.div(ACC_TOKEN_PRECISION);
                }
                mining = mining.add(temp.sub(nft.rewardDebt));
                nft.rewardDebt = temp;

                if(address(pool.dividendToken) != address(0) && pool.accDividendPerShare > 0){
                    temp = pool.accDividendPerShare.div(ACC_TOKEN_PRECISION);
                    dividend = dividend.add(temp.sub(nft.dividendDebt));
                    nft.dividendDebt = temp;
                }
            }
        }
        if (!_isInternal && pool.rewardVeToken){
            require(mining > veToken.minimumLockAmount(), "NFTMasterChef: reward too low!");
        }
        if (mining > 0) {
            if (!pool.rewardVeToken){
                _safeTransferTokenFromThis(token, _to, mining);
            }else{
                _safeLockTokenFromThis(token, _to, mining);
            }
            if(pool.rewardDevRatio > 0){
                transferToDev(pool, pool.rewardDevRatio, mining);
            }
            // pool.rewarded = pool.rewarded.add(mining);
        }
        if(dividend > 0){
            _safeTransferTokenFromThis(pool.dividendToken, _to, dividend);
        }
        emit Harvest(_to, _pid, mining, dividend);
    }

    function emergencyStop(address payable _to) public onlyOwner {
        if(_to == address(0)){
            _to = payable(msg.sender);
        }
        uint256 addrBalance = token.balanceOf(address(this));
        if(addrBalance > 0){
            token.safeTransfer(_to, addrBalance);
        }
        uint256 length = poolInfos.length;
        for (uint256 pid = 0; pid < length; ++ pid) {
            closePool(pid, _to);
        }
        emit EmergencyStop(msg.sender, _to);
    }

    function closePool(uint256 _pid, address payable _to) public validatePoolByPid(_pid) onlyOwner nonReentrant {
        PoolInfo storage pool = poolInfos[_pid];
        pool.endBlock = block.number;
        if(_to == address(0)){
            _to = payable(msg.sender);
        }
        if(address(pool.dividendToken) != address(0)){
            uint256 bal = pool.dividendToken.balanceOf(address(this));
            if(bal > 0){
                pool.dividendToken.safeTransfer(_to, bal);
            }
        }
        emit ClosePool(_pid, _to);
    }

    // Safe transfer token function, just in case if rounding error causes pool to not have enough tokens.
    function _safeLockTokenFromThis(IERC20 _token, address _to, uint256 _amount) internal {
        uint256 bal = _token.balanceOf(address(this));
        if (_amount > bal) {
            // _token.safeTransfer(_to, bal);
            _token.safeIncreaseAllowance(address(veToken), bal);
            veToken.lock(_to, bal, lockBlockNumber);
        } else {
            // _token.safeTransfer(_to, _amount);
            _token.safeIncreaseAllowance(address(veToken), _amount);
            veToken.lock(_to, _amount, lockBlockNumber);
        }
    }
    
    function safeTransferTokenFromThis(IERC20 _token, address _to, uint256 _amount) public onlyOwner nonReentrant {
        _safeTransferTokenFromThis(_token, _to, _amount);
    }

    function _safeTransferTokenFromThis(IERC20 _token, address _to, uint256 _amount) internal {
        uint256 bal = _token.balanceOf(address(this));
        if (_amount > bal) {
            _token.safeTransfer(_to, bal);
        } else {
            _token.safeTransfer(_to, _amount);
        }
    }

     // Update dev1 address by the previous dev.
    function updateDevAddress(address payable _devAddress) external nonReentrant {
        require(msg.sender == devAddress, "NFTMasterChef: dev: wut?");
        require(_devAddress != address(0), "NFTMasterChef: address can not be zero!");
        devAddress = _devAddress;
        emit UpdateDevAddress(_devAddress);
    }

    // Add reward for pool from the current block or start block, not allow to remove token reward for mining
    function addTokenRewardForPool(uint256 _pid, uint256 _addTokenPerPool, uint256 _addTokenPerNFTEachBlock, bool _withTokenTransfer) 
        external validatePoolByPid(_pid) onlyOwner nonReentrant {

        require(_addTokenPerPool > 0 || _addTokenPerNFTEachBlock > 0, "NFTMasterChef: add token must be greater than zero!");
        PoolInfo storage pool = poolInfos[_pid];
        require((pool.rewardForEachBlock > 0 && _addTokenPerPool > 0) || (pool.rewardPerNFTForEachBlock > 0 && _addTokenPerNFTEachBlock > 0), 
                "NFTMasterChef: add token error!");
        require(block.number < pool.endBlock, "NFTMasterChef: this pool is going to be end or end!");
        updatePool(_pid);
        if(_addTokenPerPool > 0){
            uint256 addTokenPerBlock;
            uint256 addTokenPerPool = _addTokenPerPool;
            uint256 start = block.number;
            uint256 end = pool.endBlock;
            if(start < pool.startBlock){
                start = pool.startBlock;
            }
            uint256 blockNumber = end.sub(start);
            if(blockNumber == 0){
                blockNumber = 1;
            }
            if(addTokenPerBlock == 0){
                addTokenPerBlock = _addTokenPerPool.div(blockNumber);
            }
            addTokenPerPool = addTokenPerBlock.mul(blockNumber);
            pool.rewardForEachBlock = pool.rewardForEachBlock.add(addTokenPerBlock);
            if(_withTokenTransfer){
                token.safeTransferFrom(msg.sender, address(this), addTokenPerPool);
            }
        }else{
            pool.rewardPerNFTForEachBlock = pool.rewardPerNFTForEachBlock.add(_addTokenPerNFTEachBlock);
        }
        emit AddTokenRewardForPool(_pid, _addTokenPerPool, _addTokenPerNFTEachBlock, _withTokenTransfer);
    }

    function addDividendForPool(uint256 _pid, uint256 _addDividend) external validatePoolByPid(_pid) onlyOwner nonReentrant {
        PoolInfo storage pool = poolInfos[_pid];
        require(_addDividend > 0, "NFTMasterChef: add token error!");
        require(address(pool.dividendToken) != address(0), "NFTMasterChef: no dividend token set!");
        require(block.number < pool.endBlock, "NFTMasterChef: this pool is going to be end or end!");

        pool.accDividendPerShare = pool.accDividendPerShare.add(_addDividend.mul(ACC_TOKEN_PRECISION).div(pool.amount));
        pool.dividendToken.safeTransferFrom(msg.sender, address(this), _addDividend);
        emit AddDividendForPool(_pid, _addDividend);
    }
}
