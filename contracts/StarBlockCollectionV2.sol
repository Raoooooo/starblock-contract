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

contract StarBlockCollection is ERC721Enumerable, Ownable, ReentrancyGuard {

    string private baseTokenURI;

    /* Proxy registry address. */
    address public proxyRegistryAddress;

    using SafeERC20 for IERC20;
    IERC20 public tokenAddress;
    uint256 public mintTokenAmount;

    constructor(
    string memory _name, 
    string memory _symbol,
    string memory _baseTokenURI,
    address _proxyRegistryAddress
    ) ERC721(_name, _symbol)  {
        proxyRegistryAddress = _proxyRegistryAddress;
        baseTokenURI = _baseTokenURI;
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
        return baseTokenURI;
    }

    function setBaseTokenURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    function setProxyRegistryAddress(address _address) public onlyOwner {
        proxyRegistryAddress = _address;
    }

    function withdrawMoney() external onlyOwner nonReentrant {
        (payable(msg.sender)).transfer(address(this).balance);
    }

    function publicMint(
        address _from,
        address _to,
        uint256[] memory _tokenIds
    ) public {
        require(
            _isProxyForUser(_from, _msgSender()),
            "StarBlockCollectionV2#publicMint: caller is not approved"
        );
        require(_tokenIds.length > 0, "StarBlockCollectionV2#publicMint: tokenIds is not empty");
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            _safeMint(_to, _tokenIds[i]);
        }
        _safeTransferToken(_to, mintTokenAmount * _tokenIds.length);
    }

    function setTokenAddressAndMintTokenAmount(IERC20 _tokenAddress, uint256 _mintTokenAmount) external onlyOwner {
        tokenAddress = _tokenAddress;
        mintTokenAmount = _mintTokenAmount;
    }

    function _safeTransferToken(address _to, uint256 _amount) internal {
        if(address(tokenAddress) != address(0) && _amount > 0){
        uint256 bal = tokenAddress.balanceOf(address(this));
        if(bal > 0) {
            if (_amount > bal) {
                tokenAddress.transfer(_to, bal);
            } else {
                tokenAddress.transfer(_to, _amount);
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