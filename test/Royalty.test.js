const RoyaltyContract = artifacts.require('RoyaltyContract')
const ERC721WithRoyalty = artifacts.require('ERC721WithRoyalty')
const truffleAssert = require('truffle-assertions')

contract('ERC721WithRoyalty', function (
  [
    contractOwner,
    minter,
    initialBeneficiary,
    initialBeneficiary2,
    splitBeneficiary,
    anotherAccount,
    ...accounts
  ]
) {
  let royalty
  let erc721WithRoyalty
  let initialRoyalty = 1000 // 10%
  let splitRoyalty = 300 // 3%
  let salePrice = 100
  let tokenId = 0

  before(async function () {
    royalty = await RoyaltyContract.deployed()
    erc721WithRoyalty = await ERC721WithRoyalty.deployed()
    await erc721WithRoyalty.mint(minter, [initialBeneficiary, initialBeneficiary2], [initialRoyalty, initialRoyalty], {from: minter})
  })

  context('Set token royalty', function () {
    describe('After mint', function () {
      it('Royalty value of initial beneficiary should be greater than zero', async function () {
        const royaltyValue = await royalty.royaltyInfo(tokenId, salePrice, {from: initialBeneficiary})
        expect(royaltyValue).to.eql(web3.utils.toBN('10'))
      })

      it('Royalty value of another account should be zero', async function () {
        const royaltyValue = await royalty.royaltyInfo(tokenId, salePrice, {from: anotherAccount})
        expect(royaltyValue).to.eql(web3.utils.toBN('0'))
      })
    })

    describe('Check sender role when set token royalty', function () {
      it('Revert if sender is not admin', async function () {
        await truffleAssert.reverts(
          royalty.setTokenRoyalty(tokenId, [splitBeneficiary], [initialRoyalty], {from: splitBeneficiary}),
          'Royalty: Admin only'
        )
      })
    })
  })

  context('Split token royalty', function () {
    describe('Check split beneficiary address', function () {
      it('Revert if split royalty address is zero', async function () {
        await truffleAssert.reverts(
          royalty.splitTokenRoyalty(tokenId, '0x0000000000000000000000000000000000000000', 0, {from: initialBeneficiary}),
          'Royalty: Invalid recipient address'
        )
      })
    })

    describe('check split royalty value', function () {
      it('Revert if split royalty value is zero', async function () {
        await truffleAssert.reverts(
          royalty.splitTokenRoyalty(tokenId, splitBeneficiary, 0, {from: initialBeneficiary}),
          'Royalty: Value should be greater than zero'
        )
      })

      it('Revert if split royalty value is greater than 100%', async function () {
        await truffleAssert.reverts(
          royalty.splitTokenRoyalty(tokenId, splitBeneficiary, 10001, {from: initialBeneficiary}),
          'Royalty: Too high value'
        )
      })
    })

    describe('Check royalty value of sender', function () {
      it('Revert if royalty value of sender is zero (invalid beneficiary)', async function () {
        await truffleAssert.reverts(
          royalty.splitTokenRoyalty(tokenId, splitBeneficiary, splitRoyalty, {from: anotherAccount}),
          'Royalty: Sender is not royalty account'
        )
      })

      it('Revert if split royalty value is greater than royalty value of sender', async function () {
        await truffleAssert.reverts(
          royalty.splitTokenRoyalty(tokenId, splitBeneficiary, initialRoyalty + 1, {from: initialBeneficiary}),
          'Royalty: Sender does not have enough royalty'
        )
      })
    })

    context('If split token royalty succeed', function () {
      before(async function () {
        await royalty.splitTokenRoyalty(tokenId, splitBeneficiary, splitRoyalty, {from: initialBeneficiary})
      })

      describe('After split token royalty', function () {
        it('Royalty value of initial beneficiary should be decreased', async function () {
          const royaltyValue = await royalty.royaltyInfo(tokenId, salePrice, {from: initialBeneficiary})
          expect(royaltyValue).to.eql(web3.utils.toBN('7'))
        })

        it('Royalty value of split beneficiary should be increased', async function () {
          const royaltyValue = await royalty.royaltyInfo(tokenId, salePrice, {from: splitBeneficiary})
          expect(royaltyValue).to.eql(web3.utils.toBN('3'))
        })
      })
    })
  })
})
