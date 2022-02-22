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

   function mintAssets(
        address _from,
        address _to,
        uint256 _collectionId,
        uint256 _numberMinted,
        uint256 _collectionSize,
        uint256 _maxPerAddressDuringMint,
        uint256 _quantity
    ) internal {

        require(
            isApprovedForAll(_from, _msgSender()),
            "StarBlockUserCollection#mintAssets: caller is not owner nor approved"
        );

       require((collectionSizeMap[_collectionId] + _quantity) <= _collectionSize, "StarBlockUserCollection#mintAssets reached max supply");
      
       require(
           (_numberMinted  + _quantity) <= _maxPerAddressDuringMint,
           "StarBlockUserCollection#mintAssets can not mint this many"
        );

        _safeMint(_from, _to, _quantity);
        collectionSizeMap[_collectionId] = collectionSizeMap[_collectionId] + _quantity;
   }

    function publicMint(
        address _from,
        address _to,
        uint256 _collectionId,
        uint256 _collectionSize,
        uint256 _maxPerAddressDuringMint,
        uint256 _quantity
    ) public whenNotPaused {

        mintAssets(_from, _to,  _collectionId, collectionNumberMinted[_collectionId][_to],
        _collectionSize, _maxPerAddressDuringMint, _quantity);
        collectionNumberMinted[_collectionId][_to] = collectionNumberMinted[_collectionId][_to] + _quantity;
    }

   function whiteListMint(
        address _from,
        address _to,
        uint256 _collectionId,
        uint256 _collectionSize,
        uint256 _maxPerAddressDuringMint,
        uint256 _quantity
    )  public whenNotPaused {

        mintAssets(_from, _to, _collectionId, collectionWhiteListNumberMinted[_collectionId][_to],
        _collectionSize, _maxPerAddressDuringMint, _quantity);
        collectionWhiteListNumberMinted[_collectionId][_to] = collectionWhiteListNumberMinted[_collectionId][_to] + _quantity;
   }
}

