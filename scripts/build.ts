import { exec as execNonPromise } from 'child_process'
import { copyFile, mkdir, readFile, rm, writeFile } from 'fs/promises'
import { join } from 'path'
import util from 'util'
import {
  BUILD_DIR,
  DEPLOYABLE_CONTRACT_NAMES,
  PROXIED_TOKEN_CONTRACT_NAMES,
} from './constants'
const exec = util.promisify(execNonPromise)

const main = async () => {
  // Clean
  try {
    await rm(BUILD_DIR, { recursive: true })
  } catch (err) {
    // Dir not found, ignore
  }

  // Build with forge
  console.log('Building contracts')
  await exec('forge build --extra-output-files metadata --force')
  console.log('Contracts built')

  await mkdir(BUILD_DIR, { recursive: true })

  // Create the compiler input files
  for (const solFile of [
    ...DEPLOYABLE_CONTRACT_NAMES,
    ...PROXIED_TOKEN_CONTRACT_NAMES,
    'TransparentUpgradeableBeaconProxy',
    'UpgradeableBeacon',
  ]) {
    const forgeOutputDir = `out/${solFile}.sol`
    const compilerDetails = JSON.parse(
      await readFile(join(forgeOutputDir, `${solFile}.metadata.json`), 'utf8'),
    )

    // Replace source urls with file contents
    for (const sourceKey of Object.keys(compilerDetails.sources)) {
      compilerDetails.sources[sourceKey] = {
        content: await readFile(join(sourceKey), 'utf8'),
      }
    }

    // Write the compiler input file
    await writeFile(
      join(BUILD_DIR, `${solFile}.input.json`),
      JSON.stringify(compilerDetails),
    )

    // Copy the compiler output too
    await copyFile(
      `${forgeOutputDir}/${solFile}.json`,
      `${BUILD_DIR}/${solFile}.json`,
    )
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
