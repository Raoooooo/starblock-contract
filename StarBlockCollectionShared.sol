// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./ERC721A.sol";

contract OwnableDelegateProxy {}

/**
 * Used to delegate ownership of a contract to another address, to save on unneeded transactions to approve contract use for users
 */
contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

contract StarBlockCollectionShared is Ownable, ERC721A, ReentrancyGuard {

  string private _baseTokenURI;

  /* Proxy registry address. */
  address public proxyRegistryAddress;

  uint256 public maxPerAddressDuringMint;

   constructor(
        string memory name_,
        string memory symbol_,
        address proxyRegistryAddress_,
        uint256 maxBatchSize_,
        uint256 collectionSize_,
        uint256 maxPerAddressDuringMint_,
        string memory baseURI_
    ) ERC721A(name_, symbol_, maxBatchSize_, collectionSize_) {

        proxyRegistryAddress = proxyRegistryAddress_;
        maxPerAddressDuringMint = maxPerAddressDuringMint_;
        if (bytes(baseURI_).length > 0) {
            setBaseURI(baseURI_);
        }
    }

     /**
     * @dev Throws if called by any account other than the owner or their proxy
     */
    modifier onlyOwnerOrProxy() {
        require(
            _isOwnerOrProxy(_msgSender()),
            "ERC1155Tradable#onlyOwner: CALLER_IS_NOT_OWNER"
        );
        _;
    }

     /**
     * Override isApprovedForAll to whitelist user proxy accounts to enable gas-less listings.
     */
    function isApprovedForAll(address owner, address operator)
        override
        public
        view
        returns (bool)
    {
        // Whitelist proxy contracts for easy trading.
        if (_isProxyForUser(owner, operator)) {
            return true;
        }
        return super.isApprovedForAll(owner, operator);
    }

    function _isOwnerOrProxy(address _address) internal view returns (bool) {
        return owner() == _address || _isProxyForUser(owner(), _address);
    }

    // PROXY HELPER METHODS
    function _isProxyForUser(address _user, address _address)
        internal
        view
        returns (bool)
    {
        return _proxy(_user) == _address;
    }

    function _proxy(address _address) internal view returns (address) {
        ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
        return address(proxyRegistry.proxies(_address));
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwnerOrProxy {
        _baseTokenURI = baseURI;
    }

    function setMaxPerAddressDuringMint(uint256 _maxPerAddressDuringMint) public onlyOwnerOrProxy {
        maxPerAddressDuringMint = _maxPerAddressDuringMint;
    }

    function setMaxBatchSize(uint256 _maxBatchSize) public onlyOwnerOrProxy {
        maxBatchSize = _maxBatchSize;
    }

    function safeMintAndTransferFrom(
        address _from,
        address _to,
        uint256 _quantity
    ) public {
      
       require(
            isApprovedForAll(_from, _msgSender()),
            "StarBlockAsset#safeMintAndTransferFrom: caller is not owner nor approved"
        );

        if (collectionSize > 0) {
            require(totalSupply() + _quantity <= collectionSize, "StarBlockAsset#safeMintAndTransferFrom reached max supply");
        }
    
       require(
            numberMinted(_to) + _quantity <= maxPerAddressDuringMint,
            "StarBlockAsset#safeMintAndTransferFrom can not mint this many"
        );

        _safeMint(_from, _to, _quantity);
    }

     function collectionMaxSize() public view returns (uint256) {
       return collectionSize;
    }

    function withdrawMoney() external onlyOwner nonReentrant {
      (bool success, ) = msg.sender.call{value: address(this).balance}("");
      require(success, "StarBlockAsset#mintAssets Transfer failed.");
    }

    function numberMinted(address owner) public view returns (uint256) {
     return _numberMinted(owner);
    }

}

