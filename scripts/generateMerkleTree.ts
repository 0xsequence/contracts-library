import { MerkleTree } from 'merkletreejs'
import { utils } from 'ethers'
import keccak256 from 'keccak256'

const generateTree = (elements: string[]) => {
  const hashed = elements.map(e => utils.solidityKeccak256(['uint256'], [e]))

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

const generateProof = (tree: MerkleTree, element: string) =>
  tree.getHexProof(utils.solidityKeccak256(['uint256'], [element]))

export { generateTree, generateProof }
