// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

abstract contract CollabProject is IERC721 {}

abstract contract NFTContract is IERC721 {
 function safeMint(string memory _trackingId, address _to, uint256 _typeId, uint numOfTokens) public {}
 function burn(uint256 tokenId) public {}
}

contract MetalordzSale is Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;
    using Strings for uint256;
    bool mintIsActive = true;
    
    // payment token
    IERC20 token;
        
    uint256 contractIndex;
    
    struct contractDetails {
        string contractName;
        NFTContract nftContract;
    }

    mapping(uint256 => contractDetails) public nftContractList;

    struct typeDetails {
        uint256 price; 
        uint256 discount;
        bool isAllowed;
    }

    // contractType => typeId => tyepDetails
    mapping(uint256 => mapping(uint256 => typeDetails)) public typeDetailsList; 

    struct collab {
        string projectName;
        CollabProject collabProject;
        uint256 discount; // project discount in bips
        bool isEnabled;
    }

    uint256 collabIndex;

    mapping(uint256 => collab) public collabProjectsList;

    struct instance {
        uint256 contractId;
        uint256 itemId;
    }

    uint256 private bundleIndex;
    mapping(uint256 => uint256) public bundlePrice;
    mapping(uint256 => instance[]) public bundleDetails;

    uint256 productIndex;

    struct product {
        string productName;
        uint256 price;
        bool isValid;
    }

    mapping(uint256 => product) public productDetails;
    
    bytes32 public merkleRoot;
    uint256 whitelistDiscount; // discount in bips

    event productSold(string orderId, uint256 productId, address purchasedBy, uint256 amountPaid, uint256 numOfUnits);

    // ADMIN FUNCTIONS // -------------------------------------------- //

    function setTokenAddress(address _tokenAddress) external onlyOwner {
        token = IERC20(_tokenAddress);
    }

    function setNFTAddresses(string memory _contractName, address _contractAddress) external onlyOwner {
        nftContractList[contractIndex].contractName = _contractName;
        nftContractList[contractIndex].nftContract = NFTContract(_contractAddress) ;
        contractIndex+=1;
    }

    function setItemTypes(uint256 _contractId, uint256[] memory _itemsList, uint256[] memory _priceList) external onlyOwner {
        require(_itemsList.length == _priceList.length,"Incorrect arguments");
        require(_contractId < contractIndex, "Incorrect Contract Id");
        for(uint i=0; i<_itemsList.length; i++) {
            typeDetailsList[_contractId][_itemsList[i]].price = _priceList[i];
        }
    }

    function setAllowedItems(uint256 _contractId, uint256[] memory _itemsList, bool _status) external onlyOwner {
        require(_contractId < contractIndex, "Incorrect Contract Id");
        for(uint i=0; i<_itemsList.length; i++) {
            typeDetailsList[_contractId][_itemsList[i]].isAllowed = _status;
        }       
    }

    // discount in bips
    function setItemDiscount(uint256 _contractId, uint256[] memory _itemsList, uint256[] memory _discount) external onlyOwner {
        require(_itemsList.length == _discount.length, "Incorrect argument");
        require(_contractId < contractIndex, "Incorrect Contract Id");
        for(uint i=0; i<_itemsList.length; i++) {
            typeDetailsList[_contractId][_itemsList[i]].discount = _discount[i];
        }
    }
    
    function withdraw() external onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
	
	function flipMintStatus() external onlyOwner {
        mintIsActive = !mintIsActive;
    }

    function setcollabProject(string memory _projectname, address _projectAddress, uint256 _discount) external onlyOwner {
        collabProjectsList[collabIndex].projectName = _projectname;
        collabProjectsList[collabIndex].collabProject = CollabProject(_projectAddress);
        collabProjectsList[collabIndex].discount = _discount;
        collabProjectsList[collabIndex].isEnabled = true;
        collabIndex+=1;
    }

    function disableCollabProject(uint256 _projectId) external onlyOwner {
        collabProjectsList[_projectId].isEnabled = false;
    }
	
	// to set the merkle root
    function updateMerkleRoot(bytes32 newmerkleRoot) external onlyOwner {
        merkleRoot = newmerkleRoot;       
    }

    function setWhitelistDiscount(uint256 _discount) external onlyOwner {
        whitelistDiscount = _discount;
    }

			
    // PUBLIC FUNCTIONS // -------------------------------------------- //

    // require this acontract to be approved bu user at token's contract
    function mintItem(string memory _trackingId, uint256 _contractId, uint256 _itemId, uint numOfTokens) public {
        require(mintIsActive, "Sale must be active to mint Equipment");
        require(_contractId < contractIndex, "Incorrect Contract Id");
        require(typeDetailsList[_contractId][_itemId].isAllowed,"Item not allowed for public mint");
        uint256 _itemPrice = typeDetailsList[_contractId][_itemId].price;
        uint256 _discount = _itemPrice.mul(typeDetailsList[_contractId][_itemId].discount).div(10000);
        uint256 netPrice = _itemPrice.sub(_discount);
        uint256 paidPrice = netPrice.mul(numOfTokens);
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= paidPrice, "Insufficient allowance");
        require(token.balanceOf(msg.sender) >= paidPrice, "Insufficient balance to buy item");
        token.transferFrom(msg.sender, address(this), paidPrice);
        nftContractList[_contractId].nftContract.safeMint(_trackingId, msg.sender, _itemId, numOfTokens);

    }

    // require this acontract to be approved bu user at token's contract
    function whitelistMintItem(string memory _trackingId, uint256 _contractId, uint256 _itemId, uint numOfTokens, bytes32[] calldata merkleProof) public {
        require(mintIsActive, "Sale must be active to mint Equipment");
        require(_contractId < contractIndex, "Incorrect Contract Id");
        require(typeDetailsList[_contractId][_itemId].isAllowed,"Item not allowed for public mint");

        // Verify the merkle proof
        require(MerkleProof.verify(merkleProof, merkleRoot,  keccak256(abi.encodePacked(msg.sender))  ), "Check proof");

        uint256 _itemPrice = typeDetailsList[_contractId][_itemId].price;
        uint256 _discount = _itemPrice.mul(typeDetailsList[_contractId][_itemId].discount).div(10000);
        uint256 netPrice = _itemPrice.sub(_discount);
        uint256 _whitelistDiscount = netPrice.mul(whitelistDiscount).div(10000);
        uint256 whitelistPrice = netPrice.sub(_whitelistDiscount);
        uint256 paidPrice = whitelistPrice.mul(numOfTokens);
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= paidPrice, "Insufficient allowance");
        require(token.balanceOf(msg.sender) >= paidPrice, "Insufficient balance to buy item");
        token.transferFrom(msg.sender, address(this), paidPrice);
        nftContractList[_contractId].nftContract.safeMint(_trackingId, msg.sender, _itemId, numOfTokens);

    }    

    // require this acontract to be approved bu user at token's contract
    function collabMintItem(string memory _trackingId, uint256 _contractId, uint256 _itemId, uint numOfTokens, uint256 _projectId, uint256 _tokenId) public {
        require(mintIsActive, "Sale must be active to mint Equipment");
        require(_contractId < contractIndex, "Incorrect Contract Id");
        require(typeDetailsList[_contractId][_itemId].isAllowed,"Item not allowed for public mint");
        require(collabProjectsList[_projectId].isEnabled == true, "Project not enabled");
        require(collabProjectsList[_projectId].collabProject.ownerOf(_tokenId) == msg.sender, "user not owner of Project NFT");
        

        uint256 _itemPrice = typeDetailsList[_contractId][_itemId].price;
        uint256 _discount = _itemPrice.mul(typeDetailsList[_contractId][_itemId].discount).div(10000);
        uint256 netPrice = _itemPrice.sub(_discount);
        uint256 _whitelistDiscount = netPrice.mul(collabProjectsList[_projectId].discount).div(10000);
        uint256 whitelistPrice = netPrice.sub(_whitelistDiscount);
        uint256 paidPrice = whitelistPrice.mul(numOfTokens);
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= paidPrice, "Insufficient allowance");
        require(token.balanceOf(msg.sender) >= paidPrice, "Insufficient balance to buy item");
        token.transferFrom(msg.sender, address(this), paidPrice);
        nftContractList[_contractId].nftContract.safeMint(_trackingId, msg.sender, _itemId, numOfTokens);

    }

    function getUserApproval() external {
        for(uint i=0; i<contractIndex; i++) {
            nftContractList[i].nftContract.setApprovalForAll(address(this), true);
        }
    }

    function burnNFTs(uint256 _contractId, uint256[] memory _itemIdArray) external onlyOwner {
        for(uint i=0; i<_itemIdArray.length; i++) {
            nftContractList[_contractId].nftContract.burn(_itemIdArray[i]);
        }
    }

    function createBundle(instance[] memory _items, uint256 _price) external onlyOwner {
        for (uint i=0; i< _items.length; i++) {
            bundleDetails[bundleIndex].push() = _items[i];
        }
        bundlePrice[bundleIndex] = _price;
        bundleIndex+=1;
    }

    function buyBundle(string memory _trackingId, uint256 _bundleId, uint256 _numOfUnits) external {
        uint256 paidPrice = bundlePrice[_bundleId].mul(_numOfUnits);
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= paidPrice, "Insufficient allowance");
        require(token.balanceOf(msg.sender) >= paidPrice, "Insufficient balance to buy item");
        token.transferFrom(msg.sender, address(this), paidPrice);
        for(uint i=0; i<bundleDetails[_bundleId].length; i++) {
            nftContractList[bundleDetails[_bundleId][i].contractId].nftContract.safeMint(_trackingId, msg.sender, bundleDetails[_bundleId][i].itemId, _numOfUnits);
        }
    }
    
    function createProduct(string memory _productName, uint256 _price) external onlyOwner {
        productDetails[productIndex].productName = _productName;
        productDetails[productIndex].price = _price;
        productDetails[productIndex].isValid = true;
        productIndex+=1;
    }

    function disableProduct(uint256 _productId) external onlyOwner {
        productDetails[_productId].isValid = false;
    }

    function buyProduct(string memory _orderId, uint256 _productId, uint256 _numOfUnits) external {
        require(productDetails[_productId].isValid,"Not a valid product");
        uint256 paidPrice = productDetails[_productId].price.mul(_numOfUnits);
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance >= paidPrice, "Insufficient allowance");
        require(token.balanceOf(msg.sender) >= paidPrice, "Insufficient balance to buy item");
        token.transferFrom(msg.sender, address(this), paidPrice);
        emit productSold(_orderId, _productId, msg.sender, paidPrice, _numOfUnits);
    }

}
