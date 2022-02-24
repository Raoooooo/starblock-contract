// SPDX-License-Identifier: MIT
pragma solidity ^0.4.13;


contract CollectionSellStrategy  {

     /**
     * @dev check if user can buy the colleciton assets.
     */
    function canBuyCollection(address buy, address sell, address collection, uint256 quantity) external view returns (bool) {
        return true;
    }
    
    /**
     * @dev update some info after buy collection
     */
    function afterBuyCollection(address buy, address sell, address collection, uint256 quantity) external returns (bool) {
        return true;
    }

}