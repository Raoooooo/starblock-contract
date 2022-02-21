// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./StarBlockBaseCollection.sol";

contract StarBlockUserCollection is StarBlockBaseCollection {

   constructor(
        string memory name_,
        string memory symbol_,
        address proxyRegistryAddress_,
        uint256 maxBatchSize_,
        uint256 collectionSize_,
        uint256 maxPerAddressDuringMint_,
        string memory baseURI_
    ) StarBlockBaseCollection(name_, symbol_, proxyRegistryAddress_, maxBatchSize_, collectionSize_, maxPerAddressDuringMint_, baseURI_) {

    }

    function mintAssets(
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

}

