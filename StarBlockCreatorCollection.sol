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
     * @param _to   Address of to
     * @param _fromTokenId tokenId
     * @param _numberMinted has mint number
     * @param _saleQuantity max sale quantity
     * @param _maxPerAddressDuringMint each to can mint max quantity
     * @param _quantity  to current mint quantity
     */
   function mintAssets(
        address _to,
        uint256 _fromTokenId,
        uint256 _numberMinted,
        uint256 _saleQuantity,
        uint256 _maxPerAddressDuringMint,
        uint256 _quantity
    ) internal {

       require((totalSupply() + _quantity) <= collectionSize, "StarBlockCreatorCollection#mintAssets reached max supply");
      
       require(
           (_numberMinted  + _quantity) <= _maxPerAddressDuringMint,
           "StarBlockCreatorCollection#mintAssets can not mint this many"
        );

        require(
            (_fromTokenId + _saleQuantity) >= (totalSupply() - 1 + _quantity),
           "StarBlockCreatorCollection#mintAssets can not mint this many"
        );

       _safeMint(address(0), _to, _quantity);
   }

    function publicMint(
        address _to,
        uint256 _fromTokenId,
        uint256 _saleQuantity,
        uint256 _maxPerAddressDuringMint,
        uint256 _quantity
    ) public onlyOwnerOrProxy whenNotPaused {

        mintAssets(_to, _fromTokenId, numberMinted(_to), _saleQuantity, _maxPerAddressDuringMint, _quantity);
    }

     /**
     * @dev whitelists whiteListMint functionality
     * @param _to   Address of reciver
     * @param _fromTokenId tokenId
     * @param _saleQuantity max sale quantity
     * @param _maxPerAddressDuringMint each reciver can mint max quantity
     * @param _quantity  reciver current mint quantity
     */
   function whiteListMint(
        address _to,
        uint256 _fromTokenId,
        uint256 _saleQuantity,
        uint256 _maxPerAddressDuringMint,
        uint256 _quantity
    ) public onlyOwnerOrProxy whenNotPaused {

       mintAssets(_to, _fromTokenId, whiteListNumberMinted[_to], _saleQuantity, _maxPerAddressDuringMint, _quantity);
       whiteListNumberMinted[_to] = whiteListNumberMinted[_to] + _quantity;
   }

}

