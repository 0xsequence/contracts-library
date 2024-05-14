import { MerkleTree } from 'merkletreejs'
import { BigNumberish, utils } from 'ethers'
import keccak256 from 'keccak256'

export type TreeElement = {
  address: string
  tokenId: BigNumberish
}

const generateTree = (elements: TreeElement[]) => {
  const hashed = elements.map(e => getLeaf(e))

  const merkleTree = new MerkleTree(hashed, keccak256, {
    sort: true,
    sortPairs: true,
    sortLeaves: true,
  })

  return {
    merkleTree,
    root: merkleTree.getHexRoot(),
  }
}

const getLeaf = (element: TreeElement) =>
  utils.solidityKeccak256(
    ['address', 'uint256'],
    [element.address.toLowerCase(), element.tokenId],
  )

const generateProof = (tree: MerkleTree, element: TreeElement) =>
  tree.getHexProof(getLeaf(element))

export { generateTree, generateProof, getLeaf }
