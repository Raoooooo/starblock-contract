// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./StarBlockBaseCollection.sol";

contract StarBlockCreatorCollection is StarBlockBaseCollection {

  /* whiteList number minted. */
  mapping(address => uint256) public whiteListNumberMinted;

   constructor(
        string memory name_,
        string memory symbol_,
        address proxyRegistryAddress_,
        uint256 maxBatchSize_,
        uint256 collectionSize_,
        string memory baseURI_
    ) StarBlockBaseCollection(name_, symbol_, proxyRegistryAddress_, maxBatchSize_, collectionSize_, baseURI_) {
       
    }

     /**
     * @dev Throws if called by any account other than the owner or their proxy
     */
    modifier onlyOwnerOrProxy() {
        require(
            _isOwnerOrProxy(_msgSender()),
            "StarBlockCreatorCollection#onlyOwnerOrProxy: CALLER_IS_NOT_OWNER"
        );
        _;
    }

    function _isOwnerOrProxy(address _address) internal view returns (bool) {
        return owner() == _address || _isProxyForUser(owner(), _address);
    }

     /**
     * @dev mint asstes functionality
     * @param to_   Address of to
     * @param fromTokenId_ tokenId
     * @param numberMinted_ has mint number
     * @param saleQuantity_  collection max sale quantity
     * @param maxPerAddressDuringMint_ each to can mint max quantity
     * @param quantity_  to current mint quantity
     */
   function _mintAssets(
        address to_,
        uint256 fromTokenId_,
        uint256 numberMinted_,
        uint256 saleQuantity_,
        uint256 maxPerAddressDuringMint_,
        uint256 quantity_
    ) internal {

       if (collectionSize > 0) {
          require((totalSupply() + quantity_) <= collectionSize, "StarBlockCreatorCollection#mintAssets reached max supply");
       }

       if (maxPerAddressDuringMint_ > 0) {
          require(
           (numberMinted_ + quantity_) <= maxPerAddressDuringMint_,
           "StarBlockCreatorCollection#mintAssets reached per address max supply"
        );
       }

       if (saleQuantity_ > 0) {
         require(
         (fromTokenId_ <= totalSupply()) && ((fromTokenId_ + saleQuantity_ - 1) >= (totalSupply() + quantity_ - 1)),
           "StarBlockCreatorCollection#mintAssets mint tokenId between fromTokenId_ and (fromTokenId_ + saleQuantity_ - 1)"
        );
       }

       _safeMint(address(0), to_, quantity_);
   }

    function publicMint(
        address to_,
        uint256 fromTokenId_,
        uint256 saleQuantity_,
        uint256 maxPerAddressDuringMint_,
        uint256 quantity_
    ) public onlyOwnerOrProxy whenNotPaused {

        _mintAssets(to_, fromTokenId_, numberMinted(to_), saleQuantity_, maxPerAddressDuringMint_, quantity_);
    }

     /**
     * @dev whitelists whiteListMint functionality
     * @param to_   Address of reciver
     * @param fromTokenId_ tokenId
     * @param saleQuantity_ max sale quantity
     * @param maxPerAddressDuringMint_ each reciver can mint max quantity
     * @param quantity_  reciver current mint quantity
     */
   function whiteListMint(
        address to_,
        uint256 fromTokenId_,
        uint256 saleQuantity_,
        uint256 maxPerAddressDuringMint_,
        uint256 quantity_
    ) public onlyOwnerOrProxy whenNotPaused {

       _mintAssets(to_, fromTokenId_, whiteListNumberMinted[to_], saleQuantity_, maxPerAddressDuringMint_, quantity_);
       whiteListNumberMinted[to_] = whiteListNumberMinted[to_] + quantity_;
   }

}
