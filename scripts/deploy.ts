import { readFile } from 'fs/promises'
import { join } from 'path'
import { BUILD_DIR, DEPLOYABLE_CONTRACT_NAMES } from './constants'
import { config as dotenvConfig } from 'dotenv'
import {
  ContractFactory,
  ContractTransaction,
  Signer,
  Wallet,
  ethers,
} from 'ethers'
import { JsonRpcProvider } from '@ethersproject/providers'

dotenvConfig()

const { PRIVATE_KEY, RPC_URL, FACTORY_OWNER } = process.env

const MAX_GAS_LIMIT = 6000000

const singletonFactoryFactory = {
  address: '0xce0042B868300000d44A59004Da54A005ffdcf9f',
  abi: [
    {
      constant: false,
      inputs: [
        {
          internalType: 'bytes',
          type: 'bytes',
        },
        {
          internalType: 'bytes32',
          type: 'bytes32',
        },
      ],
      name: 'deploy',
      outputs: [
        {
          internalType: 'address payable',
          type: 'address',
        },
      ],
      payable: false,
      stateMutability: 'nonpayable',
      type: 'function',
    },
  ],
}

const main = async () => {
  if (!PRIVATE_KEY || !RPC_URL || !FACTORY_OWNER) {
    throw new Error('Environment vars not set')
  }

  // Prep deployer wallet
  const provider = new JsonRpcProvider(RPC_URL)
  const wallet = new Wallet(PRIVATE_KEY, provider)

  // Create deployer factory
  const singletonFactory = new ethers.Contract(
    singletonFactoryFactory.address,
    singletonFactoryFactory.abi,
    wallet,
  )

  // Get deployment files from build dir
  for (const solFile of DEPLOYABLE_CONTRACT_NAMES) {
    console.log(`Deploying ${solFile}`)

    // Create contract for deployment
    const compilerOutput = JSON.parse(
      await readFile(join(BUILD_DIR, `${solFile}.json`), 'utf8'),
    )
    class MyContractFactory extends ContractFactory {
      constructor(signer?: Signer) {
        super(compilerOutput.abi, compilerOutput.bytecode.object, signer)
      }
    }
    const contract = new MyContractFactory(wallet)
    const contractCode = contract.getDeployTransaction(FACTORY_OWNER).data
    if (!contractCode) {
      throw new Error(`${solFile} did not return contract code`)
    }

    // Check if already deployed
    const address = ethers.utils.getAddress(
      ethers.utils.hexDataSlice(
        ethers.utils.keccak256(
          ethers.utils.solidityPack(
            ['bytes1', 'address', 'bytes32', 'bytes32'],
            [
              '0xff',
              singletonFactory.address,
              ethers.constants.HashZero,
              ethers.utils.keccak256(contractCode),
            ],
          ),
        ),
        12,
      ),
    )

    if (ethers.utils.arrayify(await provider.getCode(address)).length > 0) {
      console.log(
        `Skipping ${solFile} because it has been deployed at ${address}`,
      )
      continue
    }

    const tx: ContractTransaction = await singletonFactory.deploy(
      contractCode,
      ethers.constants.HashZero,
      {
        gasLimit: MAX_GAS_LIMIT,
      },
    )
    await tx.wait()

    if (ethers.utils.arrayify(await provider.getCode(address)).length === 0) {
      throw new Error(`failed to deploy ${solFile}`)
    }

    console.log(`Deployed ${solFile} at ${address}`)
  }
}

main()
  .then(() => {
    console.log('Done')
  })
  .catch(err => {
    console.error(err)
    process.exit(1)
  })
