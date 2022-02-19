// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./BaseERC721A.sol";

contract StarBlockCollection is BaseERC721A {

   constructor(
        string memory name_,
        string memory symbol_,
        address proxyRegistryAddress_,
        uint256 maxBatchSize_,
        uint256 collectionSize_,
        uint256 maxPerAddressDuringMint_,
        string memory baseURI_
    ) BaseERC721A(name_, symbol_, proxyRegistryAddress_, maxBatchSize_, collectionSize_, baseURI_) {
        maxPerAddressDuringMint = maxPerAddressDuringMint_;
    }

    function mintAssets(
        address _to,
        uint256 _quantity
    ) public onlyOwnerOrProxy {

     if (collectionSize > 0) {
        require(totalSupply() + _quantity <= collectionSize, "StarBlockAsset#mintAssets reached max supply");
     }
    
     require(
           numberMinted(_to) + _quantity <= maxPerAddressDuringMint,
          "StarBlockAsset#mintAssets can not mint this many"
       );

       _safeMint(address(0), _to, _quantity);
    }

}

