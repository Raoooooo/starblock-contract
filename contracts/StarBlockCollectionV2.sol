// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OwnableDelegateProxy {}

/**
 * Used to delegate ownership of a contract to another address, to save on unneeded transactions to approve contract use for users
 */
contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

contract StarBlockCollectionV2 is ERC721Enumerable, Ownable, ReentrancyGuard {

   string private _baseTokenURI;

   /* Proxy registry address. */
   address public proxyRegistryAddress;

   using SafeERC20 for IERC20;
   IERC20 public tokenAddress;
   uint256 public mintTokenAmount;

    constructor(
    string memory _name, 
    string memory _symbol,
    string memory baseURI,
    address _proxyRegistryAddress
    ) ERC721(_name, _symbol)  {
         proxyRegistryAddress = _proxyRegistryAddress;
         _baseTokenURI = baseURI;
    }

      // PROXY HELPER METHODS
    function _isProxyForUser(address _user, address _address)
        internal
        view
        returns (bool) {
        return _proxy(_user) == _address;
    }

    function _proxy(address _address) internal view returns (address) {
        ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
        return address(proxyRegistry.proxies(_address));
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    function setProxyRegistryAddress(address _address) public onlyOwner {
        proxyRegistryAddress = _address;
    }`

     function withdrawMoney() external onlyOwner nonReentrant {
         (payable(msg.sender)).transfer(address(this).balance);
    }

    function publicMint(
        address _from,
        address _to,
        uint256[] _tokenIds
    ) public {
         require(
            _isProxyForUser(_from, _msgSender()),
            "StarBlockCollectionV2#mintAssets: caller is not approved"
        );
        // _safeMint(_to, _tokenId);
        // for () {

        // }
        safeTransferToken(_to, mintTokenAmount);
    }

   function setTokenAddressAndMintTokenAmount(IERC20 tokenAddress_, uint256 mintTokenAmount_) external onlyOwner {
        tokenAddress = tokenAddress_;
        mintTokenAmount = mintTokenAmount_;
   }

   function safeTransferToken(address to_, uint256 amount_) internal {
      if(address(tokenAddress) != address(0) && amount_ > 0){
        uint256 bal = tokenAddress.balanceOf(address(this));
        if(bal > 0) {
            if (amount_ > bal) {
                tokenAddress.transfer(to_, bal);
            } else {
                tokenAddress.transfer(to_, amount_);
            }
        }
      }
    }

    function withdrawToken() external onlyOwner {
        uint256 bal = tokenAddress.balanceOf(address(this));
        if(bal > 0) {
            tokenAddress.transfer(msg.sender, bal);
        }
    }

}