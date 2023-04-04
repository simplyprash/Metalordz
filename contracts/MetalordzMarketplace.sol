// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MetalordzMarketplace is ReentrancyGuard, Ownable {
    using SafeMath for uint256;

    mapping(address => bool) public allowedContracts;
    IERC20 public token;
    uint256 public fee; //in bips
    address public feeWallet;

    uint256 private listingIndex;

    struct listing {
        uint256 tokenId;
        IERC721 nftContract;
        address listerAddress;
        uint256 price;
        uint256 validTill;
        uint256 status; // 0 -active, 1 - completed, 2 - revoked
    }

    // listingId => struct
    mapping(uint256 => listing) public listingDetails;

    uint256 private bidIndex;

    struct bid {
        uint256 tokenId;
        IERC721 nftContract;
        address bidderAddress;
        uint256 offerPrice;
        uint256 validTill;
        uint256 status; // 0 - active, 1 - accepted, 2 - revoked
    }

    // bidId => bidDetails
    mapping(uint256 => bid) public bidDetails;

    uint256 private bundleIndex;

    struct bundleListing {
        uint256[] tokenId;
        IERC721[] nftContract;
        address listerAddress;
        uint256 price;
        uint256 validTill;
        uint256 status; // 0 -active, 1 - completed, 2 - revoked
    }

    // bundleId => struct
    mapping(uint256 => bundleListing) private bundleListingDetails;

    struct bidOnBundle {
        uint256 bundleId;
        address bidderAddress;
        uint256 offerPrice;
        uint256 validTill;
        uint256 status; // 0 - active, 1 - accepted, 2 - revoked
    }

    // bundleId => bid(s) on listing
    mapping(uint256 => bidOnBundle[]) private bidOnBundleDetails;

    struct bundle {
        uint256 tokenId;
        address nftContractAddress;
    }

    // EVENTS // ------------------------------------ //

    event listedForSale(uint256 listingId, uint256 tokenId, IERC721 tokenContract, address listerAddress, uint256 price, uint256 validTill);
    event listingPriceUpdated(uint256 listingId, uint256 price);
    event listingDurationUpdated(uint256 listingId, uint256 validTill);
    event listingRevoked(uint256 listingId);
    event offerMade(uint256 bidId, uint256 tokenId, IERC721 tokenContract, address listerAddress, uint256 price, uint256 validTill);
    event bidRevoked(uint256 bidId);
    event bundleListedForSale(uint256 bundleId, address listerAddress, uint256 price, uint256 validTill);
    event bundlePriceUpdated(uint256 bundleId, uint256 price);
    event bundleDurationUpdated(uint256 bundleId, uint256 validTill);
    event bundleRevoked(uint256 bundleId);
    event offerMadeForBundle(uint256 bundleId, uint256 offerIndex, address bidderAddress, uint256 price, uint256 validTill);
    event bidRevokedForBundle(uint256 bundleId, uint256 offerIndex);
    event sold(IERC721 tokenContract, uint256 tokenId, address from, address to, uint256 price);

    receive() external payable {}

    // ADMIN FUNCTIONS // ------------------------------------ //

    function addNFTContract(address _contractAddress) external onlyOwner {
        allowedContracts[_contractAddress] = true;
    }

    function setPaymentToken(address _contractAddress) external onlyOwner {
        token = IERC20(_contractAddress);
    }

    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    function setFeeWallet(address _walletAddress) external onlyOwner {
        feeWallet = _walletAddress;
    }

    function withdrawFunds() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "Insufficient funds to withdraw");
        require(feeWallet != address(0), "Fee Wallet not set");

        token.transfer(feeWallet, balance);
    }

    // SELLER FUNCTIONS // ------------------------------------ //

    // requires approval as a pre-condition
    function createListing(uint256 _tokenId, address _nftContractAddress, uint256 _price, uint256 _duration) external {
        require(allowedContracts[_nftContractAddress] == true, "Not an allowed contract");
        IERC721 nftContract = IERC721(_nftContractAddress);
        require(nftContract.ownerOf(_tokenId) == msg.sender, "user not owner of token Id");
        require(nftContract.isApprovedForAll(msg.sender, address(this)),"Allowance to transfer NFT not provided");
        uint256 validTill = block.timestamp.add(_duration);
        listingDetails[listingIndex].tokenId = _tokenId;
        listingDetails[listingIndex].nftContract = nftContract;
        listingDetails[listingIndex].listerAddress = msg.sender;
        listingDetails[listingIndex].price = _price;
        listingDetails[listingIndex].validTill = validTill;

        emit listedForSale(listingIndex, _tokenId, nftContract, msg.sender, _price, validTill);
        listingIndex+=1;
    }

    function updateListingPrice(uint256 _listingId, uint256 _price) external {
        require(isValidListing(_listingId), "Invalid listing");
        require(listingDetails[_listingId].listerAddress == msg.sender, "Caller did not create this listing");
        require(listingDetails[_listingId].nftContract.ownerOf(listingDetails[_listingId].tokenId) == msg.sender, "Caller not owner of token Id");

        listingDetails[listingIndex].price = _price;     
        emit listingPriceUpdated(_listingId, _price);   
    }

    function extendListing(uint256 _listingId, uint256 _duration) external {
        require(isValidListing(_listingId), "Invalid listing");
        require(listingDetails[_listingId].listerAddress == msg.sender, "Caller did not create this listing");
        require(IERC721(listingDetails[_listingId].nftContract).ownerOf(listingDetails[_listingId].tokenId) == msg.sender, "user not owner of token Id");

        uint256 validTill = block.timestamp.add(_duration);
        listingDetails[_listingId].validTill = validTill;
        emit listingDurationUpdated(_listingId, validTill);
    }

    function revokeListing(uint256 _listingId) external {
        require(isValidListing(_listingId), "Invalid listing");
        require(listingDetails[_listingId].listerAddress == msg.sender, "Caller did not create this listing");
        require(IERC721(listingDetails[_listingId].nftContract).ownerOf(listingDetails[_listingId].tokenId) == msg.sender, "user not owner of token Id");

        listingDetails[_listingId].status = 2;
        emit listingRevoked(_listingId);
    }

    function acceptOffer(uint256 _bidId) external nonReentrant {
        require(isValidBid(_bidId), "Invalid bid");
        uint256 price = bidDetails[_bidId].offerPrice;
        address bidderAddress = bidDetails[_bidId].bidderAddress;
        uint256 allowance = token.allowance(bidderAddress, address(this));
        require(allowance > price, "Insufficient allowance");
        require(token.balanceOf(bidderAddress) > price, "Insufficient balance");
        IERC721 nftContract = bidDetails[_bidId].nftContract;
        uint256 tokenId = bidDetails[_bidId].tokenId;
        require(nftContract.ownerOf(tokenId) == msg.sender,"Caller is not the owner of NFT");
        require(nftContract.isApprovedForAll(msg.sender, address(this)),"Allowance to transfer NFT not provided");
        uint256 applicableFee = price.mul(fee).div(10000);
        bidDetails[_bidId].status = 1;
        token.transferFrom(bidderAddress, msg.sender, price.sub(applicableFee));
        token.transferFrom(bidderAddress, address(this), applicableFee);
        nftContract.safeTransferFrom(msg.sender, bidderAddress, tokenId);

        emit sold(nftContract, tokenId, msg.sender, bidderAddress, price);

    }


    // requires approval as a pre-condition
    function createBundleListing(bundle[] memory _bundle, uint256 _price, uint256 _duration) external {
        for( uint i=0; i< _bundle.length; i++) {
            IERC721 nftContract = IERC721(_bundle[i].nftContractAddress);
            uint256 tokenId = _bundle[i].tokenId;
            require(allowedContracts[_bundle[i].nftContractAddress] == true, "Not an allowed contract");
            require(nftContract.ownerOf(tokenId) == msg.sender, "user not owner of token Id");
            require(nftContract.isApprovedForAll(msg.sender, address(this)),"Allowance to transfer NFT not provided");

            bundleListingDetails[bundleIndex].tokenId.push() = tokenId;
            bundleListingDetails[bundleIndex].nftContract.push() = nftContract;
        }
                
        uint256 validTill = block.timestamp.add(_duration);       
        bundleListingDetails[bundleIndex].listerAddress = msg.sender;
        bundleListingDetails[bundleIndex].price = _price;
        bundleListingDetails[bundleIndex].validTill = validTill;

        emit bundleListedForSale(bundleIndex, msg.sender, _price, validTill);
        bundleIndex+=1;
    }

    function updateBundlePrice(uint256 _bundleId, uint256 _price) external {
        require(isValidBundle(_bundleId), "Invalid bundle");
        require(bundleListingDetails[_bundleId].listerAddress == msg.sender, "Caller did not create this bundle");

        bundleListingDetails[_bundleId].price = _price;     
        emit bundlePriceUpdated(_bundleId, _price);   
    }

    function extendBundle(uint256 _bundleId, uint256 _duration) external {
        require(isValidBundle(_bundleId), "Invalid bundle");
        require(bundleListingDetails[_bundleId].listerAddress == msg.sender, "Caller did not create this bundle");

        uint256 validTill = bundleListingDetails[_bundleId].validTill.add(_duration);
        bundleListingDetails[_bundleId].validTill = validTill;
        emit bundleDurationUpdated(_bundleId, validTill);
    }

    function revokeBundle(uint256 _bundleId) external {
        require(isValidBundle(_bundleId), "Invalid bundle");
        require(bundleListingDetails[_bundleId].listerAddress == msg.sender, "Caller did not create this bundle");

        bundleListingDetails[_bundleId].status = 2;
        emit bundleRevoked(_bundleId);
    }

    function acceptOfferForBundle(uint256 _bundleId, uint256 offerIndex) external nonReentrant {
        require(isValidBundle(_bundleId), "Invalid bundle");
        require(bundleListingDetails[_bundleId].listerAddress == msg.sender, "Caller did not create this bundle");

        require(isValidBidForBundle(_bundleId, offerIndex), "Invalid bid");

        uint256 price = bidOnBundleDetails[_bundleId][offerIndex].offerPrice;
        address bidderAddress = bidOnBundleDetails[_bundleId][offerIndex].bidderAddress;
        uint256 allowance = token.allowance(bidderAddress, address(this));
        require(allowance > price, "Insufficient allowance");
        require(token.balanceOf(bidderAddress) > price, "Insufficient balance");

        bidOnBundleDetails[_bundleId][offerIndex].status = 1;
        bundleListingDetails[_bundleId].status = 1;
        uint256 applicableFee = price.mul(fee).div(10000);
        token.transferFrom(bidderAddress, msg.sender, price.sub(applicableFee));
        token.transferFrom(bidderAddress, address(this), applicableFee);

        for (uint i=0; i< bundleListingDetails[_bundleId].tokenId.length; i++) {
            IERC721 nftContract = bundleListingDetails[_bundleId].nftContract[i];
            uint256 tokenId = bundleListingDetails[_bundleId].tokenId[i];
            require(nftContract.isApprovedForAll(msg.sender, address(this)),"Allowance to transfer NFT revoked by lister");
            require(nftContract.ownerOf(tokenId) == msg.sender,"Lister is not the owner of NFT anymore");

            nftContract.safeTransferFrom(msg.sender, bidderAddress, tokenId);
            emit sold(nftContract, tokenId, msg.sender, bidderAddress, 0); // price passed as 0 becuase sold as part of a bundle
        }
        
    }

    // BUYER FUNCTIONS // ------------------------------------ //

    // requires approving this contract's address as operator on token contract for 'sufficient' amount as a pre-condition
    function buy(uint256 _listingId) external nonReentrant {
        require(isValidListing(_listingId), "Invalid listing");
        address listerAddress = listingDetails[_listingId].listerAddress;
        IERC721 nftContract = listingDetails[_listingId].nftContract;
        uint256 tokenId = listingDetails[_listingId].tokenId;
        require(nftContract.isApprovedForAll(listerAddress, address(this)),"Allowance to transfer NFT revoked by lister");
        require(nftContract.ownerOf(tokenId) == listerAddress,"Lister is not the owner of NFT anymore");
        uint256 price = listingDetails[_listingId].price;
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance > price, "Insufficient allowance");
        require(token.balanceOf(msg.sender) > price, "Insufficient balance");
        uint256 applicableFee = price.mul(fee).div(10000);
        listingDetails[_listingId].status = 1;
        token.transferFrom(msg.sender, listerAddress, price.sub(applicableFee));
        token.transferFrom(msg.sender, address(this), applicableFee);
        nftContract.safeTransferFrom(listerAddress, msg.sender, tokenId);

        emit sold(nftContract, tokenId, listerAddress, msg.sender, price);
    }

    // requires approving this contract's address as operator on token contract for 'sufficient' amount as a pre-condition
    function makeOffer(uint256 _tokenId, address _nftContractAddress, uint256 _price, uint256 _duration) external {
        require(allowedContracts[_nftContractAddress] == true, "Not an allowed contract");
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance > _price, "Insufficient allowance");
        require(token.balanceOf(msg.sender) > _price, "Insufficient balance");
        uint256 validTill = block.timestamp.add(_duration);
        IERC721 nftContract = IERC721(_nftContractAddress);
        bidDetails[bidIndex].tokenId = _tokenId;
        bidDetails[bidIndex].nftContract = nftContract;
        bidDetails[bidIndex].bidderAddress = msg.sender;
        bidDetails[bidIndex].offerPrice = _price;
        bidDetails[bidIndex].validTill = validTill;

        emit offerMade(bidIndex, _tokenId, nftContract, msg.sender, _price, validTill);
        bidIndex+=1;
    }    

    function revokeOffer(uint256 _bidId) external {
        require(_bidId < bidIndex, "Invalid bid id");
        require(bidDetails[_bidId].status == 0 && bidDetails[_bidId].validTill > block.timestamp, "Inactive bid");
        require(bidDetails[_bidId].bidderAddress == msg.sender, "Caller did not create this bid");

        bidDetails[_bidId].status = 2;
        emit bidRevoked(_bidId);
    }

    // requires approving this contract's address as operator on token contract for 'sufficient' amount as a pre-condition
    function buyBundle(uint256 _bundleId) external nonReentrant {
        require(isValidBundle(_bundleId), "Invalid bundle");
        address listerAddress = bundleListingDetails[_bundleId].listerAddress;

        uint256 price = bundleListingDetails[_bundleId].price;
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance > price, "Insufficient allowance");
        require(token.balanceOf(msg.sender) > price, "Insufficient balance");
        uint256 applicableFee = price.mul(fee).div(10000);
        bundleListingDetails[_bundleId].status = 1;
        token.transferFrom(msg.sender, listerAddress, price.sub(applicableFee));
        token.transferFrom(msg.sender, address(this), applicableFee);

        for (uint i=0; i< bundleListingDetails[_bundleId].tokenId.length; i++) {
            IERC721 nftContract = bundleListingDetails[_bundleId].nftContract[i];
            uint256 tokenId = bundleListingDetails[_bundleId].tokenId[i];
            require(nftContract.isApprovedForAll(listerAddress, address(this)),"Allowance to transfer NFT revoked by lister");
            require(nftContract.ownerOf(tokenId) == listerAddress,"Lister is not the owner of NFT anymore");

            nftContract.safeTransferFrom(listerAddress, msg.sender, tokenId);
            emit sold(nftContract, tokenId, listerAddress, msg.sender, 0); // price passed as 0 because sold as part of a bundle
        } 
    
    }

    function makeOfferForBundle(uint256 _bundleId, uint256 _price, uint256 _duration) external {
        require(isValidBundle(_bundleId), "Invalid bundle");
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(allowance > _price, "Insufficient allowance");
        require(token.balanceOf(msg.sender) > _price, "Insufficient balance");
        uint256 validTill = block.timestamp.add(_duration);
        bidOnBundle memory newBidOnBundle;

        newBidOnBundle.bundleId = _bundleId;
        newBidOnBundle.bidderAddress = msg.sender;
        newBidOnBundle.offerPrice = _price;
        newBidOnBundle.validTill = validTill;
        uint256 offerIndex = bidOnBundleDetails[_bundleId].length;
        bidOnBundleDetails[_bundleId].push() = newBidOnBundle;

        emit offerMadeForBundle(_bundleId, offerIndex, msg.sender, _price, validTill);
    }    

    function revokeOfferForBundle(uint256 _bundleId, uint256 offerIndex) external {
        require(isValidBundle(_bundleId), "Invalid bundle");
        require(isValidBidForBundle(_bundleId, offerIndex), "Invalid bid");
        require(bidOnBundleDetails[_bundleId][offerIndex].bidderAddress == msg.sender, "Bid not made by the caller");

        bidOnBundleDetails[_bundleId][offerIndex].status = 2;
        emit bidRevokedForBundle(_bundleId, offerIndex);
    }

    // READ FUNCTIONS // ------------------------------------ //

    function getAllBidsOnBundle(uint256 _bundleId) public view returns(bidOnBundle[] memory bidsOnBundle) {
        uint length = bidOnBundleDetails[_bundleId].length;
        bidOnBundle[] memory _bidsOnBundle = new bidOnBundle[](length);

        for (uint i=0; i<length; i++) {
            _bidsOnBundle[i].bundleId = bidOnBundleDetails[_bundleId][i].bundleId;
            _bidsOnBundle[i].bidderAddress = bidOnBundleDetails[_bundleId][i].bidderAddress;
            _bidsOnBundle[i].offerPrice = bidOnBundleDetails[_bundleId][i].offerPrice;
            _bidsOnBundle[i].validTill = bidOnBundleDetails[_bundleId][i].validTill;
            _bidsOnBundle[i].status = bidOnBundleDetails[_bundleId][i].status;

        }

        return _bidsOnBundle;

    }

    function getBundleDetails(uint256 _bundleId) public view returns(bundle[] memory tokens, address listerAddress, uint256 price, uint256 validTill, uint256 status) {
        uint length = bundleListingDetails[_bundleId].tokenId.length;
        bundle[] memory _tokens = new bundle[](length);

        for (uint i=0; i< length; i++) {
            _tokens[i].tokenId = bundleListingDetails[_bundleId].tokenId[i];
            _tokens[i].nftContractAddress = address(bundleListingDetails[_bundleId].nftContract[i]);
        }

        return(_tokens, bundleListingDetails[_bundleId].listerAddress, bundleListingDetails[_bundleId].price, bundleListingDetails[_bundleId].validTill, bundleListingDetails[_bundleId].status);
               
    }

    // INTERNAL FUNCTIONS //------------------------------------------------/

    function isValidListing(uint256 _listingId) internal view returns(bool) {
        if(_listingId < listingIndex && listingDetails[_listingId].status == 0 && listingDetails[_listingId].validTill > block.timestamp) return true; else return false;
    }

    function isValidBundle(uint256 _bundleId) internal view returns(bool) {
        if(_bundleId < bundleIndex && bundleListingDetails[_bundleId].status == 0 && bundleListingDetails[_bundleId].validTill > block.timestamp) return true; else return false;
    }

    function isValidBid(uint256 _bidId) internal view returns(bool) {
        if(_bidId < bidIndex && bidDetails[_bidId].status == 0 && bidDetails[_bidId].validTill > block.timestamp) return true; else return false;
    }

    function isValidBidForBundle(uint256 _bundleId, uint256 offerIndex) internal view returns(bool) {
        if(bidOnBundleDetails[_bundleId][offerIndex].bundleId == _bundleId && bidOnBundleDetails[_bundleId][offerIndex].status == 0 && bidOnBundleDetails[_bundleId][offerIndex].validTill > block.timestamp) return true; else return false;
    } 

}
