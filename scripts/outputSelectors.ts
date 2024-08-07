import { PROXIED_TOKEN_CONTRACT_NAMES } from './constants'

const { spawn } = require('child_process')

const outputSelectors = (contractName: string) => {
  const inspect = spawn('forge', [
    'inspect',
    '--pretty',
    contractName,
    'method_identifiers',
  ])

  let output = ''

  inspect.stdout.on('data', (data: string) => {
    output += data
  })

  inspect.stderr.on('data', (data: string) => {
    console.error(`stderr: ${data}`)
  })

  inspect.on('close', (code: number) => {
    console.log(`child process exited with code ${code}`)
    const selectorData = JSON.parse(output)
    // Iterate through object keys
    console.log(contractName)
    Object.keys(selectorData).forEach((key: string) => {
      console.log(`checkSelectorCollision(0x${selectorData[key]}); // ${key}`)
    })
  })
}

PROXIED_TOKEN_CONTRACT_NAMES.forEach(outputSelectors)
