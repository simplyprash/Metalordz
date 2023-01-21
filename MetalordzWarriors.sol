
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "./IERC4907.sol";

contract MetalordzWarriors is ERC721, ERC721Burnable, IERC4907, ERC2981, AccessControl, Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    using Strings for uint256;
    string public baseURI;
    Counters.Counter private _tokenIdCounter;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE"); 
  
    // warriorsTypes
    mapping(uint256 => bool) public isWarriors;
    // token Id to warriors Type Id mapping
    mapping(uint256 => uint256) public warriorsType;   

    // UserInfo needed for implementation of IERC4907
    struct UserInfo {
        address user; // address of user role
        uint64 expires; // unix timestamp, user expires
    }

    mapping(uint256 => UserInfo) internal _users;

    constructor() ERC721("MetaLordz Warriors", "METALORDZ WARRIORS") {}

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // OWNER FUNCTIONS // --------------------------------------------- //

    function setMinterRole(address _address) external onlyOwner {
        _grantRole(MINTER_ROLE, _address);
    }

    function setAdminRole(address _address) external onlyOwner {
        _grantRole(ADMIN_ROLE, _address);
    }

    // ADMIN FUNCTIONS // -------------------------------------------- //

    function setRoyaltyInfo(address _receiver, uint96 _royaltyFeesInBips) public onlyRole(ADMIN_ROLE) {
        _setDefaultRoyalty(_receiver, _royaltyFeesInBips);
    }

    function setWarriorsTypes(uint256[] memory _warriorsTypes) external onlyRole(ADMIN_ROLE) {
        for (uint i=0; i<_warriorsTypes.length; i++) {
            isWarriors[i] = true;
        }
    }

    // to be set with a '/' in the end
    function setBaseURI(string calldata _baseURI) external onlyRole(ADMIN_ROLE) {
        baseURI = _baseURI;
    }

    function mintBulkWarriors(uint256 _warriorsTypeId, uint numOfTokens) external onlyRole(ADMIN_ROLE) {
        require(isWarriors[_warriorsTypeId] == true, "Not a valid warriors type");
        for (uint i=0; i< numOfTokens; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _safeMint(msg.sender, tokenId);
            warriorsType[tokenId] = _warriorsTypeId;
            _tokenIdCounter.increment();
        }
    }

    function mintBulkWarriorsDistributed(uint256[] memory warriorsTypeArray, uint numOfTokens) external onlyRole(ADMIN_ROLE) {
        uint len = warriorsTypeArray.length;
        for (uint i=0; i< numOfTokens; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _safeMint(msg.sender, tokenId);
            uint256 _warriorsTypeId = warriorsTypeArray[i.mod(len)]; //equal distribution of members of warriors type Array
            warriorsType[tokenId] = _warriorsTypeId;
            _tokenIdCounter.increment();
        }
    }

    // MINTER FUNCTIONS // -------------------------------------------- //
    
    function safeMint(address _to, uint256 _warriorsTypeId, uint numOfTokens) public onlyRole(MINTER_ROLE) {
        require(isWarriors[_warriorsTypeId] == true, "Not a valid warriors type");

        for (uint i=0; i< numOfTokens; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _safeMint(_to, tokenId);
            warriorsType[tokenId] = _warriorsTypeId;
            _tokenIdCounter.increment();
        }
    }

    // PUBLIC FUNCTIONS // -------------------------------------------- //

    function setUser(uint256 tokenId, address user, uint64 expires) public virtual override {
		require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: transfer caller is not owner nor approved");
		UserInfo storage info = _users[tokenId];
		info.user = user;
		info.expires = expires;
		emit UpdateUser(tokenId, user, expires);
	}

    function userOf(uint256 tokenId) public view virtual override returns (address) {
		if (uint256(_users[tokenId].expires) >= block.timestamp) {
			return _users[tokenId].user;
		} else {
			return address(0);
		}
	}

	function userExpires(uint256 tokenId) public view virtual override returns (uint256) {
		return _users[tokenId].expires;
	}

    function totalSupply() public view returns(uint256) {
        uint256 supply = _tokenIdCounter.current();
        return supply;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId),"Token Id does not exist");
        string memory output = string(abi.encodePacked(baseURI, Strings.toString(tokenId), ".json"));
        return output;
    }

}
