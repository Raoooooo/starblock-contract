// SPDX-License-Identifier: MIT
// StarBlock Contracts

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./wnft_interfaces.sol";
import "./ArrayUtils.sol";

contract WrappedNFT is IWrappedNFT, ERC721Royalty, IERC721Receiver, Ownable, ReentrancyGuard, Pausable {
    using ArrayUtils for uint256[];

    string public constant NAME_PREFIX = "Wrapped ";
    string public constant SYMBOL_PREFIX = "W-";

    IWrappedNFTFactory public factory;// can not changed
    IERC721Metadata public nft;
    address public admin; //NFTMasterChef Contract

    uint256 public totalSupply;

    //only admin can deposit or withdraw for other user.
    modifier checkForUser(address _forUser) {
        // require(msg.sender == admin || (_forUser == address(0) || _forUser == msg.sender), "WrappedNFT: not allowed!");
        require(msg.sender == admin || (_forUser == address(0) || _forUser == msg.sender), "WrappedNFT: not allowed!");
        _;
    }

    constructor(
        IERC721Metadata _nft
    ) ERC721("", "") {
        nft = _nft;
        factory = IWrappedNFTFactory(msg.sender);
        admin = factory.wnftAdmin();
        _setDefaultRoyalty(factory.wnftRoyaltyReceiver(), factory.wnftRoyaltyFeeNumerator());
        transferOwnership(factory.wnftOwner());
    }

    //allow wnftAdmin to zero
    function setAdmin(address _admin) external onlyOwner nonReentrant {
        admin = _admin;
        emit SetAdmin(_admin);
    }

    function deposit(address _forUser, uint256[] memory _tokenIds) external nonReentrant whenNotPaused checkForUser(_forUser) { 
        require(_tokenIds.length > 0, "WrappedNFT: tokenIds can not be empty!");
        require(!_tokenIds.hasDuplicate(), "WrappedNFT: tokenIds can not contain duplicate ones!");

        if(_forUser == address(0)){
            _forUser = msg.sender;
        }

        uint256 tokenId;
        for(uint256 i = 0; i < _tokenIds.length; i ++){
            tokenId = _tokenIds[i];
            require(nft.ownerOf(tokenId) == _forUser, "WrappedNFT: can not deposit nft not owned!");
            nft.safeTransferFrom(_forUser, address(this), tokenId);
            if(_exists(tokenId)){
                // require(ownerOf(tokenId) == address(this), "WrappedNFT: tokenId owner error!");
                _transfer(address(this), _forUser, tokenId);
                //TODO 查查为什么不能用这个
                // safeTransferFrom(address(this), _forUser, tokenId);
            }else{
                _safeMint(_forUser, tokenId);
            }
        }
        emit Deposit(_forUser, _tokenIds);
    }

    function withdraw(address _forUser, uint256[] memory _wnftTokenIds) external nonReentrant checkForUser(_forUser) {
        require(_wnftTokenIds.length > 0, "WrappedNFT: tokenIds can not be empty!");
        require(!_wnftTokenIds.hasDuplicate(), "WrappedNFT: tokenIds can not contain duplicate ones!");

        if(_forUser == address(0)){
            _forUser = msg.sender;
        }

        uint256 tokenId;
        for(uint256 i = 0; i < _wnftTokenIds.length; i ++){
            tokenId = _wnftTokenIds[i];
            require(ownerOf(tokenId) == _forUser, "WrappedNFT: can not withdraw nft not owned!");
            // _safeBurn(tokenId);
            safeTransferFrom(_forUser, address(this), tokenId);
            //TODO test if needed
            // if(nft.getApproved(tokenId) != address(this)){
            //     nft.approve(_forUser, tokenId);
            // }
            nft.safeTransferFrom(address(this), _forUser, tokenId);
        }

        emit Withdraw(_forUser, _wnftTokenIds);
    }

    // function _baseURI() internal view virtual override returns (string memory) {
    //     return nft.baseURI();
    // }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override(IERC721Metadata, ERC721) returns (string memory) {
        return string(abi.encodePacked(NAME_PREFIX, nft.name()));
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override(IERC721Metadata, ERC721) returns (string memory) {
        return string(abi.encodePacked(SYMBOL_PREFIX, nft.symbol()));
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 _tokenId) public view override(ERC721, IERC721Metadata) returns (string memory) {
        require(_exists(_tokenId), "WrappedNFT: URI query for nonexistent token");
        return nft.tokenURI(_tokenId);
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function exists(uint256 _tokenId) external view virtual returns (bool) {
        return _exists(_tokenId);
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal override virtual {
        _safeMint(to, tokenId, "");
        totalSupply ++;
    }

    function _safeBurn(uint256 tokenId) internal virtual {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: _safeBurn caller is not owner nor approved");
        _burn(tokenId);
        totalSupply --;
    }

    // function defaultRoyaltyInfo() public view virtual override returns (address _receiver, uint256 _royaltyFraction) {
    //     return (_defaultRoyaltyInfo.receiver, _defaultRoyaltyInfo.royaltyFraction);
    // }

    /**
     * @dev Sets the royalty information that all ids in this contract will default to.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) external virtual onlyOwner nonReentrant {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    /**
     * @dev Removes default royalty information.
     */
    function deleteDefaultRoyalty() external virtual onlyOwner nonReentrant {
        _deleteDefaultRoyalty();
    }

    /**
     * @dev Sets the royalty information for a specific token id, overriding the global default.
     *
     * Requirements:
     *
     * - `receiver` cannot be the zero address.
     * - `feeNumerator` cannot be greater than the fee denominator.
     */
    function setTokenRoyalty(
        uint256 _tokenId,
        address _receiver,
        uint96 _feeNumerator
    ) external virtual onlyOwner nonReentrant {
        _setTokenRoyalty(_tokenId, _receiver, _feeNumerator);
    }

    function onERC721Received (
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) public virtual override returns (bytes4) {
        //TODO 合约收到一个ERC721以后会调用的方法，如果有这个方法了，是不是可以收到以后自动给一个WNFT呢？
        //TODO 这块可以检查，只收NFT和WNFT两个合约的NFT。
        return this.onERC721Received.selector;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function pause() external virtual whenNotPaused {
        _pause();
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function unpause() external virtual whenPaused {
        _unpause();
    }
}

contract WrappedNFTFactory is IWrappedNFTFactory, Ownable, ReentrancyGuard {
    address public wnftOwner;   //used for setting Royalty
    address public wnftAdmin;   //NFTMasterChef Contract, used to deposit for withdraw for other user in WNFT.
    address public wnftRoyaltyReceiver;
    uint96 public wnftRoyaltyFeeNumerator;

    mapping(IERC721Metadata => IWrappedNFT) public wnfts;
    uint256 public wnftsNumber;

    constructor (
        address _wnftOwner,
        address _wnftRoyaltyReceiver,
        uint96 _wnftRoyaltyFeeNumerator //div 10000 when used, can not greater than 10000
    ) {
        require(_wnftOwner != address(0) && _wnftRoyaltyReceiver != address(0), "WrappedNFTFactory: invalid!");
        wnftOwner = _wnftOwner;
        wnftRoyaltyReceiver = _wnftRoyaltyReceiver;
        wnftRoyaltyFeeNumerator = _wnftRoyaltyFeeNumerator;
    }

    function deployWrappedNFT(IERC721Metadata _nft) external onlyOwner nonReentrant returns (IWrappedNFT wnft) {
        require(address(_nft) != address(0), "WrappedNFTFactory: _nft can not be zero!");
        require(address(wnfts[_nft]) == address(0), "WrappedNFTFactory: wnft has been deployed!");
        // require(bytes(_nft.name()).length > 0 && bytes(_nft.symbol()).length > 0, "WrappedNFT: name and symbol must not be empty!");
        wnft = new WrappedNFT(_nft);
        wnfts[_nft] = wnft;
        wnftsNumber ++;
        emit WrappedNFTDeployed(_nft, wnft);
    }

    function setWNFTOwner(address _wnftOwner) external onlyOwner nonReentrant {
        require(_wnftOwner != address(0), "WrappedNFTFactory: _wnftOwner can not be zero!");
        wnftOwner = _wnftOwner;
        emit WNFTOwnerChanged(_wnftOwner);
    }

    //allow wnftAdmin to zero
    function setWNFTAdmin(address _wnftAdmin) external onlyOwner nonReentrant {
        wnftAdmin = _wnftAdmin;
        emit WNFTAdminChanged(_wnftAdmin);
    }

    function setWNFTRoyaltyInfo(address _wnftRoyaltyReceiver, uint96 _wnftRoyaltyFeeNumerator) external onlyOwner nonReentrant {
        require(_wnftRoyaltyReceiver != address(0), "WrappedNFTFactory: _wnftRoyaltyReceiver can not be zero!");
        wnftRoyaltyReceiver = _wnftRoyaltyReceiver;
        wnftRoyaltyFeeNumerator = _wnftRoyaltyFeeNumerator;
        emit WNFTRoyaltyInfoChanged(_wnftRoyaltyReceiver, _wnftRoyaltyFeeNumerator);
    }
}