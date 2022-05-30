// SPDX-License-Identifier: MIT
// StarBlock DAO Contracts

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

import "./wnft_interfaces.sol";
import "./ArrayUtils.sol";

abstract contract BaseWrappedNFT is Ownable, ReentrancyGuard, ERC721, ERC2981, IBaseWrappedNFT {
    using ArrayUtils for uint256[];
    
    string public constant NAME_PREFIX = "Wrapped ";
    string public constant SYMBOL_PREFIX = "W";

    IWrappedNFTFactory public immutable factory;// can not changed
    IERC721Metadata public immutable nft;
    bool public isEnumerable;

    address public delegator; //who can help user to deposit and withdraw NFT, need user to approve

    //only delegator can deposit or withdraw for other user.
    modifier userSelfOrDelegator(address _forUser) {
        // require(msg.sender == delegator || (_forUser == address(0) || _forUser == msg.sender), "WrappedNFT: not allowed!");
        require(msg.sender == delegator || (_forUser == address(0) || _forUser == msg.sender), "BaseWrappedNFT: not allowed!");
        _;
    }

    constructor(
        IERC721Metadata _nft
    ) ERC721("", "") {
        nft = _nft;
        factory = IWrappedNFTFactory(msg.sender);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721, ERC2981) returns (bool) {
        return interfaceId == type(IBaseWrappedNFT).interfaceId || interfaceId == type(IERC721Receiver).interfaceId 
                || interfaceId == type(IERC2981Mutable).interfaceId || ERC721.supportsInterface(interfaceId) || ERC2981.supportsInterface(interfaceId);
    }

    //allow delegator to zero
    function setDelegator(address _delegator) external onlyOwner nonReentrant {
        delegator = _delegator;
        emit DelegatorChanged(_delegator);
    }

    function _requireTokenIds(uint256[] memory _tokenIds) internal pure {
        require(_tokenIds.length > 0, "BaseWrappedNFT: tokenIds can not be empty!");
        require(!_tokenIds.hasDuplicate(), "BaseWrappedNFT: tokenIds can not contain duplicate ones!");
    }

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    // function ownerOf(uint256 tokenId) external view returns (address owner);

    // function deposit(address _forUser, uint256[] memory _tokenIds) external nonReentrant whenNotPaused userSelfOrDelegator(_forUser) { 
    function deposit(address _forUser, uint256[] memory _tokenIds) external nonReentrant userSelfOrDelegator(_forUser) { 
        _requireTokenIds(_tokenIds);

        if(_forUser == address(0)){
            _forUser = msg.sender;
        }
        
        uint256 tokenId;
        for(uint256 i = 0; i < _tokenIds.length; i ++){
            tokenId = _tokenIds[i];
            require(nft.ownerOf(tokenId) == _forUser, "BaseWrappedNFT: can not deposit nft not owned!");
            nft.safeTransferFrom(_forUser, address(this), tokenId);
            if(_exists(tokenId)){
                require(ownerOf(tokenId) == address(this), "BaseWrappedNFT: tokenId owner error!");
                _transfer(address(this), _forUser, tokenId);
                //TODO 查查为什么不能用这个，也许应该也用下面safe这个？
                // safeTransferFrom(address(this), _forUser, tokenId);
            }else{
                //TODO 测试super和非super有啥区别，super的这种子类如果集成了这个_safeMint怎么办，可以用子类的么？
                _safeMint(_forUser, tokenId);
            }
        }
        emit Deposit(_forUser, _tokenIds);
    }

    function withdraw(address _forUser, uint256[] memory _wnftTokenIds) external nonReentrant userSelfOrDelegator(_forUser) {
        _requireTokenIds(_wnftTokenIds);

        if(_forUser == address(0)){
            _forUser = msg.sender;
        }

        uint256 wnftTokenId;
        for(uint256 i = 0; i < _wnftTokenIds.length; i ++){
            wnftTokenId = _wnftTokenIds[i];
            require(ownerOf(wnftTokenId) == _forUser, "BaseWrappedNFT: can not withdraw nft not owned!");
            // _safeBurn(wnftTokenId);
            safeTransferFrom(_forUser, address(this), wnftTokenId);
            //TODO test if needed
            // if(nft.getApproved(wnftTokenId) != address(this)){
            //     nft.approve(_forUser, wnftTokenId);
            // }
            nft.safeTransferFrom(address(this), _forUser, wnftTokenId);
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
    function tokenURI(uint256 _tokenId) public view virtual override(IERC721Metadata, ERC721) returns (string memory) {
        require(ERC721._exists(_tokenId), "BaseWrappedNFT: URI query for nonexistent token");
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
    function exists(uint256 _tokenId) external view returns (bool) {
        return _exists(_tokenId);
    }

    function onERC721Received (
        address,
        address,
        uint256,
        bytes calldata
    ) public virtual override returns (bytes4) {
        //TODO 合约收到一个ERC721以后会调用的方法，如果有这个方法了，是不是可以收到以后自动给一个WNFT呢？
        //TODO 这块可以检查，只收NFT和WNFT两个合约的NFT。
        return this.onERC721Received.selector;
    }

    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) external onlyOwner nonReentrant {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    function deleteDefaultRoyalty() external onlyOwner nonReentrant {
        _deleteDefaultRoyalty();
    }
}

//add total supply for etherscan get
contract WrappedNFT is IWrappedNFT, BaseWrappedNFT {
    uint256 private _totalSupply;

    constructor(
        IERC721Metadata _nft
    ) BaseWrappedNFT(_nft) {
        isEnumerable = false;
    }
    
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, BaseWrappedNFT) returns (bool) {
        return interfaceId == type(IWrappedNFT).interfaceId || BaseWrappedNFT.supportsInterface(interfaceId);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        ERC721._beforeTokenTransfer(from, to, tokenId);
        if (from == address(0)) {
            _totalSupply ++;
        } else if (to == address(0)) {
            _totalSupply --;
        } 
    }

    function totalSupply() public view virtual override returns (uint256){
        return _totalSupply;
    }
}

contract WrappedNFTEnumerable is IWrappedNFTEnumerable, WrappedNFT, ERC721Enumerable {
    constructor(
        IERC721Metadata _nft
    ) WrappedNFT(_nft) {
        isEnumerable = true;
    }
    
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, WrappedNFT, ERC721Enumerable) returns (bool) {
        return interfaceId == type(IWrappedNFTEnumerable).interfaceId || WrappedNFT.supportsInterface(interfaceId) || ERC721Enumerable.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(WrappedNFT, ERC721Enumerable) {
        ERC721Enumerable._beforeTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override(IERC721Metadata, ERC721) returns (string memory) {
        return BaseWrappedNFT.name();
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override(IERC721Metadata, ERC721) returns (string memory) {
        return BaseWrappedNFT.symbol();
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 _tokenId) public view virtual override(IERC721Metadata, ERC721) returns (string memory) {
        return BaseWrappedNFT.tokenURI(_tokenId);
    }

    function totalSupply() public view override(IWrappedNFTEnumerable, ERC721Enumerable, WrappedNFT) returns (uint256){
        return ERC721Enumerable.totalSupply();
    }
}

//support deploy 2 WNFT: ERC721 and ERC721Enumerable implementation.
contract WrappedNFTFactory is IWrappedNFTFactory, Ownable, ReentrancyGuard {
    address public wnftDelegator;   //NFTMasterChef Contract, used to deposit for withdraw for other user in WNFT.

    mapping(IERC721Metadata => IWrappedNFT) public wnfts;
    uint256 public wnftsNumber;

    function deployWrappedNFT(IERC721Metadata _nft, bool _isEnumerable) external onlyOwner nonReentrant returns (IWrappedNFT wnft) {
        require(address(_nft) != address(0), "WrappedNFTFactory: _nft can not be zero!");
        require(address(wnfts[_nft]) == address(0), "WrappedNFTFactory: wnft has been deployed!");
        // require(bytes(_nft.name()).length > 0 && bytes(_nft.symbol()).length > 0, "WrappedNFT: name and symbol must not be empty!");
        if(_isEnumerable){
            wnft = new WrappedNFTEnumerable(_nft);
        }else{
            wnft = new WrappedNFT(_nft);
        }
        if(wnftDelegator != address(0)){
            wnft.setDelegator(wnftDelegator);
        }
        Ownable(address(wnft)).transferOwnership(owner());
        //TODO Test open it
        wnfts[_nft] = wnft;
        wnftsNumber ++;
        emit WrappedNFTDeployed(_nft, wnft, _isEnumerable);
    }
    
    //allow wnftDelegator to zero
    function setWNFTDelegator(address _wnftDelegator) external onlyOwner nonReentrant {
        wnftDelegator = _wnftDelegator;
        emit WNFTDelegatorChanged(_wnftDelegator);
    }
}
