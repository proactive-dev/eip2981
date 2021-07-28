const Royalty = artifacts.require("Royalty");
const ERC721WithRoyalty = artifacts.require("ERC721WithRoyalty");

module.exports = async function (deployer) {
  // Deploy both contract
  await deployer.deploy(Royalty);
  const royalty = await Royalty.deployed();
  await deployer.deploy(ERC721WithRoyalty, 'PriviNFTRoyalty', 'PNR');
  const erc721WithRoyalty = await ERC721WithRoyalty.deployed();

  // set contract related states
  let result = await erc721WithRoyalty.setRoyaltyContract(royalty.address)
  console.log(result)
  result = await royalty.setAdmin(erc721WithRoyalty.address)
  console.log(result)
};
