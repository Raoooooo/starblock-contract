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
     * @dev mint asstes functionality
     * @param to_   Address of to
     * @param fromTokenId_ tokenId
     * @param numberMinted_ has mint number
     * @param saleQuantity_  collection max sale quantity
     * @param maxPerAddressDuringMint_ each to can mint max quantity
     * @param quantity_  to current mint quantity
     */
   function mintAssets(
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
           "StarBlockCreatorCollection#mintAssets address can not mint this many"
        );
       }

       if (saleQuantity_ > 0) {
         require(
            (fromTokenId_ + saleQuantity_) >= (totalSupply() - 1 + quantity_),
           "StarBlockCreatorCollection#mintAssets collection can not mint this many"
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

        mintAssets(to_, fromTokenId_, numberMinted(to_), saleQuantity_, maxPerAddressDuringMint_, quantity_);
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

       mintAssets(to_, fromTokenId_, whiteListNumberMinted[to_], saleQuantity_, maxPerAddressDuringMint_, quantity_);
       whiteListNumberMinted[to_] = whiteListNumberMinted[to_] + quantity_;
   }

}

