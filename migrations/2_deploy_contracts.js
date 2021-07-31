const RoyaltyContract = artifacts.require("RoyaltyContract");
const ERC721WithRoyalty = artifacts.require("ERC721WithRoyalty");

module.exports = async function (deployer) {
  // Deploy both contract
  await deployer.deploy(RoyaltyContract);
  const royalty = await RoyaltyContract.deployed();
  await deployer.deploy(ERC721WithRoyalty, 'PriviNFTRoyalty', 'PNR');
  const erc721WithRoyalty = await ERC721WithRoyalty.deployed();

  // const royalty = await RoyaltyContract.at('0xDD64357ce7eD4B8CC1871ed5Af9ec50BCF6724fd')
  // const erc721WithRoyalty = await ERC721WithRoyalty.at('0x00c55c8E428Fcb44933f0F64444Cb2aFFFAD4BA8')
  // set contract related states
  let result = await erc721WithRoyalty.setRoyaltyContract(royalty.address)
  console.log(result)
  result = await royalty.setAdmin(erc721WithRoyalty.address)
  console.log(result)
};
