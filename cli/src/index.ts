#!/usr/bin/env node

import { program } from "commander";
import log from "loglevel";
import util from "util";
import { createTestCoin, getTestCoinBalance, TestCoinSymbol, TEST_COINS, getBalance } from "./test-coins";
import { initializeFerum, initializeMarket, addLimitOrder, addMarketOrder, cancelOrder } from "./market";
import { AptosAccount, HexString } from "aptos";
import { Types } from "aptos";
import { publishModuleUsingCLI } from "./utils/module-publish-utils";
import { getClient, getFaucetClient, getNodeURL } from './aptos-client';
import { setEnv } from './utils/env';
import Config, { CONFIG_PATH } from './config';
import { initializeUSDF, registerUSDF, mintUSDF } from './usdf';
import { testModuleUsingCLI } from "./utils/module-testing-utils";

const DEFAULT_CONTRACT_DIR = "../contract"

// Register test coin symbols with ferum account alias.
for (let symbol in TEST_COINS) {
  Config.setAliasForType(symbol, TEST_COINS[symbol as TestCoinSymbol]);
}

log.setLevel("info");

setEnv('devnet');

program.version("1.1.0", undefined, "Output the version number.");

program.option("-l, --log-level <string>", "Log level")
  .hook('preAction', (cmd, subCmd) => {
    const { logLevel } = cmd.opts();
    setLogLevel(logLevel);
  });

program.option("-e, --env <string>", "Environment to use. Valid options are devnet or testnet")
  .hook('preAction', (cmd, subCmd) => {
    const { env } = cmd.opts();
    if (!env) {
      return
    }
    if (env === 'devnet') {
      setEnv(env);
    } else if (env === 'testnet') {
      setEnv(env);
    } else {
      log.error('Invalid environment')
      throw new Error();
    }
  });

program.command("init-account")
  .description('Initializes an aptos account.')
  .requiredOption('-pk, --private-key <string>', 'Private key of the account')
  .requiredOption('-a, --address <string>', 'Address of the account')
  .action(async (_, cmd) => {
    const { address, privateKey } = cmd.opts();
    const account = AptosAccount.fromAptosAccountObject({
      privateKeyHex: privateKey,
      address,
    });
    await getFaucetClient().fundAccount(account.address(), 2_000_000_00000000);
    log.info(`Created account ${account.address()}`);
  });

program.command("fund-account")
  .description('Funds the specified account with 2,000,000 APT.')
  .option('-a, --address <string>', 'Address of the account')
  .action(async (_, cmd) => {
    let { address } = cmd.opts();
    if (!address) {
      const profile = Config.getCurrentProfileName();
      if (!profile) {
        log.error('Need to specify an address or have a profile set.');
        throw new Error('No address to fund');
      }
      address = Config.getProfileAccount(profile).address();
    } 
    await getFaucetClient().fundAccount(address, 2_000_000_00000000);
    log.info(`Funded account ${address} with 2,000,000 APT`);
  });

program.command("create-profile")
  .description('Initializes a profile.')
  .requiredOption('-n, --name <string>', 'Name for profile')
  .action(async (_, cmd) => {
    const { name } = cmd.opts();
    await Config.createNewProfile(name);
    Config.setCurrentProfile(name);
    log.info(`Created profile ${name} and selected it as the current one`);
  });

program.command("import-existing-profile")
  .description('Imports an existing profile.')
  .requiredOption('-n, --name <string>', 'Name for profile')
  .requiredOption("-pk, --private-key [string]", "Private key assoicated with the existing profile.")
  .requiredOption("-fa, --ferumAccount [string]", "Address of the published ferum module.")
  .action(async (_, cmd) => {
    const { name, privateKey, ferumAccount } = cmd.opts();
    await Config.importExistingProfile(name, privateKey, ferumAccount);
    Config.setCurrentProfile(name);
    log.info(`Added profile ${name} and selected it as the current one`);
  });

program.command("set-current-profile")
  .description('Sets specified profile as the current.')
  .requiredOption('-n, --name <string>', 'Name of profile')
  .action(async (_, cmd) => {
    const { name } = cmd.opts();
    try {
      Config.setCurrentProfile(name);
    }
    catch {
      log.info(`${name} is not a profile. Create it using create-profile`);
      return;
    }

    log.info('Current profile is now', name);
  });

program.command("show-current-profile")
  .description('Shows the current profile.')
  .action(async (_, cmd) => {
    const name = Config.getCurrentProfileName();
    if (!name) {
      log.info('Current profile not set. Set it using set-current-profile');
      return;
    }
    prettyPrint(`Current profile: ${name}`, Config.getProfileAccount(name).toPrivateKeyObject());
  });

program.command("show-type-aliases")
  .description('Show the type aliases that are currently set.')
  .action(async (_, cmd) => {
    prettyPrint('Defined Aliases symbols', Config.getTypeAliasMap());
  });

program.command("set-type-alias")
  .description('Set an alias for a type. The alias can then be used as arguments to any command instead of the fully qualified type.')
  .requiredOption(
    "-t, --type <string>",
    `Fully qualified type for  (address::module::type). If address in the type is omitted, ` +
    `the public address for DefaultModulePrivateKey in ${CONFIG_PATH} is used.`
  )
  .requiredOption("-a, --alias <string>", "Alias for the type.")
  .action(async (_, cmd) => {
    const { type, alias } = cmd.opts();
    Config.setAliasForType(alias, type);
    log.info(`Set symbol for coin type ${type} to ${alias}.`);
  });

program.command("clear-type-alias")
  .description('Clear a type alias.')
  .requiredOption("-a, --alias <string>", "Name of type alias.")
  .action(async (_, cmd) => {
    const { alias } = cmd.opts();
    if (Config.clearAlias(alias)) {
      log.info(`Cleared type alias ${alias}.`);
    }
  });

program.command("get-address")
  .option("-pk, --private-key [string]", "Private key of the account to get the address for.")
  .action(async (_, cmd) => {
    const { privateKey } = cmd.opts();
    const privateKeyHex = Uint8Array.from(Buffer.from(privateKey, "hex"));
    const account = new AptosAccount(privateKeyHex);
    log.info(`Address: ${account.address().toString()}`);
  });

signedCmd("publish-ferum")
  .requiredOption("-m, --module-path <string>", "Module path.", DEFAULT_CONTRACT_DIR)
  .option("-g, --max-gas [number]", "Max gas used for transaction. Optional. Defaults to 10000.", "10000")
  .action(async (_, cmd) => {
    const { account, modulePath, maxGas } = cmd.opts();
    const maxGasNum = parseNumber(maxGas, 'max-gas');
    log.info('Publishing modules under account', account.address().toString());
    try {
      await publishModuleUsingCLI(getNodeURL(), account, modulePath, maxGasNum);
      Config.setFerumAddress((account as AptosAccount).address().toString());
    }
    catch {
      console.error('Unable to publish module.');
    }
  });

signedCmd("test-ferum")
  .requiredOption("-m, --module-path <string>", "Module path.", DEFAULT_CONTRACT_DIR)
  .action(async (_, cmd) => {
    const { account, modulePath } = cmd.opts();
    log.info('Testing modules under account', account.address().toString());
    try {
      await testModuleUsingCLI(getNodeURL(), account, modulePath);
    }
    catch {
      console.error('Unable to publish module.');
    }
  });

signedCmd("create-test-coins")
  .description('Create FakeMoneyA (FMA) and FakeMoneyB (FMB) test coins.')
  .action(async (_, cmd) => {
    const { account } = cmd.opts();
    await createTestCoin(account, "FMA");
    await createTestCoin(account, "FMB");
  });

signedCmd("create-usdf")
  .description('Creates USDF coins for testing.')
  .action(async (_, cmd) => {
    const { account } = cmd.opts();
    const txHash = await initializeUSDF(account);
    log.info(`Started pending transaction: ${txHash}.`)
    const txResult = await getClient().waitForTransactionWithResult(txHash) as Types.UserTransaction;
    prettyPrint(transactionStatusMessage(txResult), txResult)
  });


signedCmd("apt-balance")
.description('Get APT coin balance for the current profile.')
.action(async (_, cmd) => {
  const { account } = cmd.opts();
  let balance = await getBalance(
    account.address(),
    "0x1::aptos_coin::AptosCoin",
  );
  prettyPrint("Coin balance:", balance);
});


signedCmd("test-coin-balances")
  .description('Get FakeMoneyA (FMA) and FakeMoneyB (FMB) balances for the signing account.')
  .action(async (_, cmd) => {
    const { account } = cmd.opts();
    const balances: { [key: string]: number } = {};
    for (let coinSymbol in TEST_COINS) {
      balances[coinSymbol] = await getTestCoinBalance(account, coinSymbol as TestCoinSymbol);
    }
    prettyPrint("Coin Balances", balances);
  });


signedCmd("init-ferum")
  .action(async (_, cmd) => {
    const { account } = cmd.opts();
    const txHash = await initializeFerum(account)
    log.info(`Started pending transaction: ${txHash}.`)
    const txResult = await getClient().waitForTransactionWithResult(txHash) as Types.UserTransaction;
    prettyPrint(transactionStatusMessage(txResult), txResult)
  });

signedCmd("init-market")
  .requiredOption(
    "-ic, --instrument-coin-type <string>",
    "Instrument CoinType. Must be a fully qualified type (address::module::CoinType) or an alias."
  )
  .requiredOption(
    "-id, --instrument-decimals <number>",
    "Decimal places for the instrument coin type. Must be <= coin::decimals(InstrumentCointType)." +
    "The sum of the instrument and quote decimals must also be <= " +
    "min(coin::decimals(InstrumentCoinType), coin::decimals(QuoteCoinType))"
  )
  .requiredOption(
    "-qc, --quote-coin-type <string>",
    "Quote CoinType. Must be a fully qualified type (address::module::CoinType) or an alias."
  )
  .requiredOption(
    "-qd, --quote-decimals <number>",
    "Decimal places for the quote coin type. Must be <= coin::decimals(QuoteCoinType). " +
    "The sum of the instrument and quote decimals must also be <= " +
    "min(coin::decimals(InstrumentCoinType), coin::decimals(QuoteCoinType))"
  )
  .action(async (_, cmd) => {
    const { account, quoteDecimals, instrumentDecimals } = cmd.opts();
    let { quoteCoinType, instrumentCoinType } = cmd.opts();

    quoteCoinType = Config.tryResolveAlias(quoteCoinType);
    instrumentCoinType = Config.tryResolveAlias(instrumentCoinType);

    const instrumentDecimalsNum = parseNumber(instrumentDecimals, 'instrument-decimals');
    const quoteDecimalsNum = parseNumber(quoteDecimals, 'quote-decimals');

    const txHash = await initializeMarket(account, instrumentCoinType, instrumentDecimalsNum, quoteCoinType, quoteDecimalsNum);
    log.info(`Started pending transaction: ${txHash}.`)
    const txResult = await getClient().waitForTransactionWithResult(txHash) as Types.UserTransaction;
    prettyPrint(transactionStatusMessage(txResult), txResult)
  });

signedCmd("add-limit-order")
  .requiredOption(
    "-ic, --instrument-coin-type <string>",
    "Instrument CoinType. Must be a fully qualified type (address::module::CoinType) or an alias."
  )
  .requiredOption(
    "-qc, --quote-coin-type <string>",
    "Quote CoinType. Must be a fully qualified type (address::module::CoinType) or an alias."
  )
  .requiredOption(
    "-p, --price <number>",
    "Limit price for the order, in terms of coin::Coin<QuoteCoinType>.",
  )
  .requiredOption(
    "-q, --quantity <number>",
    "Quantity for the order, in terms of coin::Coin<InstrumentCoinType>",
  )
  .requiredOption(
    "-s, --side <buy | sell>",
    "Side for the order, either buy or sell.",
  )
  .action(async (_, cmd) => {
    const { account, price, quantity, side } = cmd.opts();
    let { quoteCoinType, instrumentCoinType } = cmd.opts();

    quoteCoinType = Config.tryResolveAlias(quoteCoinType);
    instrumentCoinType = Config.tryResolveAlias(instrumentCoinType);

    const txHash = await addLimitOrder(account, instrumentCoinType, quoteCoinType, side, price, quantity)
    log.info(`Started pending transaction: ${txHash}.`)
    const txResult = await getClient().waitForTransactionWithResult(txHash) as Types.UserTransaction;
    prettyPrint(transactionStatusMessage(txResult), txResult)
  });

signedCmd("add-market-order")
  .requiredOption(
    "-ic, --instrument-coin-type <string>",
    "Instrument CoinType. Must be a fully qualified type (address::module::CoinType) or an alias."
  )
  .requiredOption(
    "-qc, --quote-coin-type <string>",
    "Quote CoinType. Must be a fully qualified type (address::module::CoinType) or an alias."
  )
  .requiredOption(
    "-q, --quantity <number>",
    "Quantity for the order, in terms of coin::Coin<InstrumentCoinType>",
  )
  .requiredOption(
    "-s, --side <buy | sell>",
    "Side for the order, either buy or sell.",
  )
  .requiredOption(
    "-c, --max-collateral [number]",
    "Only required for a buy order. Max amount of coin::Coin<QuoteCoinType> allowed to be spent.",
  )
  .action(async (_, cmd) => {
    const { account, side, quantity, maxCollateral } = cmd.opts();
    let { quoteCoinType, instrumentCoinType } = cmd.opts();

    quoteCoinType = Config.tryResolveAlias(quoteCoinType);
    instrumentCoinType = Config.tryResolveAlias(instrumentCoinType);

    const txHash = await addMarketOrder(account, instrumentCoinType, quoteCoinType, side, quantity, maxCollateral)
    log.info(`Started pending transaction: ${txHash}.`)
    const txResult = await getClient().waitForTransactionWithResult(txHash) as Types.UserTransaction;
    prettyPrint(transactionStatusMessage(txResult), txResult)
  });


signedCmd("cancel-order")
  .requiredOption(
    "-ic, --instrument-coin-type <string>",
    "Instrument CoinType. Must be a fully qualified type (address::module::CoinType) or an alias."
  )
  .requiredOption(
    "-qc, --quote-coin-type <string>",
    "Quote CoinType. Must be a fully qualified type (address::module::CoinType) or an alias."
  )
  .requiredOption("-id, --order-id <number>", "Order id.")
  .action(async (_, cmd) => {
    const { account, orderID } = cmd.opts();
    let { quoteCoinType, instrumentCoinType } = cmd.opts();

    quoteCoinType = Config.tryResolveAlias(quoteCoinType);
    instrumentCoinType = Config.tryResolveAlias(instrumentCoinType);

    const txHash = await cancelOrder(account, instrumentCoinType, quoteCoinType, orderID)
    log.info(`Started pending transaction: ${txHash}.`)
    const txResult = await getClient().waitForTransactionWithResult(txHash) as Types.UserTransaction;
    prettyPrint(transactionStatusMessage(txResult), txResult)
  });

//
// Helpers
//

function signedCmd(name: string) {
  return program.command(name)
    .option(
      "-pk, --private-key <string>",
      `Private key of account used to sign transaction. Will fallback to profile-name if not set.`,
    )
    .option(
      "-pn, --profile <string>",
      `Name of profile to use to sign this transaction. Will fallback to current profile if not set.`,
    )
    .hook('preAction', cmd => {
      const { privateKey, profileName } = cmd.opts();
      let account;
      if (privateKey) {
        account = new AptosAccount(Uint8Array.from(Buffer.from(privateKey)));
      }
      else if (profileName) {
        account = Config.getProfileAccount(profileName);
      }
      else {
        try {
          const name = Config.getCurrentProfileName();
          account = Config.getProfileAccount(name);
        }
        catch {
          throw new Error(
            'No profile selected. Create a new one using create-profile or set an existing one using set-current-profile',
          );
        }
      }
      cmd.setOptionValue('account', account);
    });
}

// eslint-disable-next-line @typescript-eslint/no-unused-vars
function setLogLevel(value: any) {
  if (value === undefined || value === null) {
    return;
  }
  log.info("Setting the log level to:", value, '\n');
  log.setLevel(value);
}

function prettyPrint(description: string, obj: any) {
  log.info(description);
  log.info(util.inspect(obj, { colors: true, depth: 6, compact: false }));
}

function transactionStatusMessage(txResult: Types.UserTransaction) {
  return txResult.success ? (
    'Transaction Succeded'
  ) : (
    'Transaction Failed'
  );
}

function parseNumber(n: any, paramName: string): number {
  const out = Number(n);
  if (Number.isNaN(out)) {
    throw new Error(`Invalid number for ${paramName} param`);
  }
  return out;
}

program.parseAsync(process.argv);