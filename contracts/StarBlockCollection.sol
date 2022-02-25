// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./StarBlockBaseCollection.sol";

contract StarBlockCollection is StarBlockBaseCollection {

   mapping(uint256 => uint256) public collectionSizeMap;
   mapping(uint256 => mapping(address => uint256)) public collectionNumberMinted;
   mapping(uint256 => mapping(address => uint256)) public collectionWhiteListNumberMinted; 
  
   constructor(
        string memory name_,
        string memory symbol_,
        address proxyRegistryAddress_,
        uint256 maxBatchSize_,
        uint256 collectionSize_,
        string memory baseURI_
    ) StarBlockBaseCollection(name_, symbol_, proxyRegistryAddress_, maxBatchSize_, collectionSize_, baseURI_) {

    }

   function _mintAssets(
        address from_,
        address to_,
        uint256 collectionId_,
        uint256 numberMinted_,
        uint256 collectionSize_,
        uint256 maxPerAddressDuringMint_,
        uint256 quantity_
    ) internal {

        require(
            isApprovedForAll(from_, _msgSender()),
            "StarBlockCollection#mintAssets: caller is not owner nor approved"
        );

        if (collectionSize_ > 0) {
            require((collectionSizeMap[collectionId_] + quantity_) <= collectionSize_, "collection can not mint this many");
        }

        if (maxPerAddressDuringMint_ > 0) {
            require(
           (numberMinted_ + quantity_) <= maxPerAddressDuringMint_,
           "StarBlockCollection#mintAssets address can not mint this many"
         );
        }

        _safeMint(from_, to_, quantity_);
        collectionSizeMap[collectionId_] = collectionSizeMap[collectionId_] + quantity_;
   }

    function publicMint(
        address from_,
        address to_,
        uint256 collectionId_,
        uint256 collectionSize_,
        uint256 maxPerAddressDuringMint_,
        uint256 quantity_
    ) public whenNotPaused {

        _mintAssets(from_, to_,  collectionId_, collectionNumberMinted[collectionId_][to_],
        collectionSize_, maxPerAddressDuringMint_, quantity_);
        collectionNumberMinted[collectionId_][to_] = collectionNumberMinted[collectionId_][to_] + quantity_;
    }

   function whiteListMint(
        address from_,
        address to_,
        uint256 collectionId_,
        uint256 collectionSize_,
        uint256 maxPerAddressDuringMint_,
        uint256 quantity_
    )  public whenNotPaused {

        _mintAssets(from_, to_, collectionId_, collectionWhiteListNumberMinted[collectionId_][to_],
        collectionSize_, maxPerAddressDuringMint_, quantity_);
        collectionWhiteListNumberMinted[collectionId_][to_] = collectionWhiteListNumberMinted[collectionId_][to_] + quantity_;
   }
}

