import { Interface, getAddress, keccak256, toUtf8Bytes } from "ethers";

import { ensureWalletOnExpectedChain } from "./auth";
import type { RuntimeConfig } from "./runtime-config";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const GAS_LIMIT_BUFFER_BPS = 12000n;
const BASIS_POINTS_DIVISOR = 10000n;

type FeeHintDefaults = {
  minMaxFeePerGas: bigint;
  minMaxPriorityFeePerGas: bigint;
};

type TransactionRequest = {
  from: string;
  to: string;
  data: string;
  gas?: string;
  gasPrice?: string;
  maxFeePerGas?: string;
  maxPriorityFeePerGas?: string;
};

type BlockFeeData = {
  baseFeePerGas?: string;
};

const allowanceInterface = new Interface([
  "function allowance(address owner, address spender) view returns (uint256)",
]);
const approveInterface = new Interface([
  "function approve(address spender, uint256 amount)",
]);
const playInterface = new Interface([
  "function play(uint256 amount, address potentialReferrer, bytes32 gameId)",
]);

export type VerifiedPayment = {
  verified: boolean;
  status: string;
  chainId: number;
  adapterAddress: string;
  txHash: string;
  logIndex: number;
  blockNumber: number;
  confirmations: number;
  player: string;
  amountPaid: string;
  netAmount: string;
  potentialReferrer: string;
  gameId: string;
  gameIdUuid: string;
};

function getEthereumProvider(): EthereumProvider {
  if (window.ethereum === undefined) {
    throw new Error(
      "No injected wallet found. Open Evanopolis in a wallet-enabled browser.",
    );
  }

  return window.ethereum;
}

function getFeeHintDefaults(expectedChainId: string): FeeHintDefaults {
  if (expectedChainId === "421614") {
    return {
      minMaxFeePerGas: 100000000n,
      minMaxPriorityFeePerGas: 10000000n,
    };
  }

  return {
    minMaxFeePerGas: 0n,
    minMaxPriorityFeePerGas: 0n,
  };
}

function normalizeBaseUrl(url: string): string {
  return url.trim().replace(/\/$/, "");
}

function toRpcHex(value: bigint): string {
  return `0x${value.toString(16)}`;
}

function multiplyByBps(value: bigint, basisPoints: bigint): bigint {
  return (value * basisPoints) / BASIS_POINTS_DIVISOR;
}

function maxBigInt(...values: Array<bigint | null>): bigint | null {
  let currentMax: bigint | null = null;

  for (const value of values) {
    if (value === null) {
      continue;
    }

    if (currentMax === null || value > currentMax) {
      currentMax = value;
    }
  }

  return currentMax;
}

async function getEstimatedGas(
  provider: EthereumProvider,
  transaction: TransactionRequest,
): Promise<bigint | null> {
  try {
    const result = await provider.request<string>({
      method: "eth_estimateGas",
      params: [transaction],
    });
    return BigInt(result);
  } catch {
    return null;
  }
}

async function getLatestBaseFeePerGas(
  provider: EthereumProvider,
): Promise<bigint | null> {
  try {
    const block = await provider.request<BlockFeeData>({
      method: "eth_getBlockByNumber",
      params: ["latest", false],
    });
    if (typeof block.baseFeePerGas !== "string") {
      return null;
    }

    return BigInt(block.baseFeePerGas);
  } catch {
    return null;
  }
}

async function getGasPrice(provider: EthereumProvider): Promise<bigint | null> {
  try {
    const result = await provider.request<string>({
      method: "eth_gasPrice",
    });
    return BigInt(result);
  } catch {
    return null;
  }
}

async function getMaxPriorityFeePerGas(
  provider: EthereumProvider,
): Promise<bigint | null> {
  try {
    const result = await provider.request<string>({
      method: "eth_maxPriorityFeePerGas",
    });
    return BigInt(result);
  } catch {
    return null;
  }
}

async function buildBufferedTransactionRequest(args: {
  provider: EthereumProvider;
  runtimeConfig: RuntimeConfig;
  from: string;
  to: string;
  data: string;
}): Promise<TransactionRequest> {
  const transaction: TransactionRequest = {
    from: args.from,
    to: args.to,
    data: args.data,
  };
  const feeHintDefaults = getFeeHintDefaults(args.runtimeConfig.expectedChainId);
  const [estimatedGas, latestBaseFeePerGas, gasPrice, maxPriorityFeePerGas] =
    await Promise.all([
      getEstimatedGas(args.provider, transaction),
      getLatestBaseFeePerGas(args.provider),
      getGasPrice(args.provider),
      getMaxPriorityFeePerGas(args.provider),
    ]);

  if (estimatedGas !== null) {
    transaction.gas = toRpcHex(
      multiplyByBps(estimatedGas, GAS_LIMIT_BUFFER_BPS),
    );
  }

  if (latestBaseFeePerGas !== null) {
    const effectivePriorityFeePerGas = maxBigInt(
      maxPriorityFeePerGas,
      feeHintDefaults.minMaxPriorityFeePerGas,
    );
    const bufferedMaxFeePerGas = maxBigInt(
      latestBaseFeePerGas * 5n +
        (effectivePriorityFeePerGas ?? feeHintDefaults.minMaxPriorityFeePerGas),
      gasPrice === null ? null : gasPrice * 2n,
      feeHintDefaults.minMaxFeePerGas,
    );

    if (bufferedMaxFeePerGas !== null && bufferedMaxFeePerGas > 0n) {
      transaction.maxFeePerGas = toRpcHex(bufferedMaxFeePerGas);
    }

    if (
      effectivePriorityFeePerGas !== null &&
      effectivePriorityFeePerGas > 0n
    ) {
      transaction.maxPriorityFeePerGas = toRpcHex(effectivePriorityFeePerGas);
    }

    return transaction;
  }

  const bufferedGasPrice = maxBigInt(
    gasPrice === null ? null : gasPrice * 2n,
    feeHintDefaults.minMaxFeePerGas,
  );
  if (bufferedGasPrice !== null && bufferedGasPrice > 0n) {
    transaction.gasPrice = toRpcHex(bufferedGasPrice);
  }

  return transaction;
}

function getWalletErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }

  if (
    typeof error === "object" &&
    error !== null &&
    "message" in error &&
    typeof error.message === "string"
  ) {
    return error.message;
  }

  return String(error);
}

function getPaymentSpecificErrorMessage(error: unknown): string | null {
  const walletMessage = getWalletErrorMessage(error).toLowerCase();

  if (walletMessage.includes("max fee per gas less than block base fee")) {
    return "Your wallet submitted a stale gas fee below the current network base fee. Retry the transaction with a higher fee, or clear any stuck wallet activity and submit again.";
  }

  return null;
}

export function deriveGameIdBytes32(gameId: string): string {
  return keccak256(toUtf8Bytes(`evanopolis:v1:${gameId}`));
}

export function normalizeWalletAddress(address: string): string | null {
  const trimmedAddress = address.trim();
  if (trimmedAddress.length === 0) {
    return null;
  }

  try {
    return getAddress(trimmedAddress);
  } catch {
    return null;
  }
}

export function getPotentialReferrerAddress(referrerAddress: string): string {
  return normalizeWalletAddress(referrerAddress) ?? ZERO_ADDRESS;
}

async function sendTransaction(args: {
  runtimeConfig: RuntimeConfig;
  to: string;
  data: string;
}): Promise<string> {
  const provider = getEthereumProvider();
  await ensureWalletOnExpectedChain(args.runtimeConfig);
  const accounts = await provider.request<string[]>({
    method: "eth_requestAccounts",
  });
  const from = accounts[0];

  if (typeof from !== "string" || from.length === 0) {
    throw new Error("The wallet did not return an account.");
  }

  const transaction = await buildBufferedTransactionRequest({
    provider,
    runtimeConfig: args.runtimeConfig,
    from,
    to: args.to,
    data: args.data,
  });

  return provider.request<string>({
    method: "eth_sendTransaction",
    params: [transaction],
  });
}

export async function getAllowance(
  runtimeConfig: RuntimeConfig,
  ownerAddress: string,
): Promise<bigint> {
  const provider = getEthereumProvider();
  const data = allowanceInterface.encodeFunctionData("allowance", [
    ownerAddress,
    runtimeConfig.paymentHandlerAddress,
  ]);
  const result = await provider.request<string>({
    method: "eth_call",
    params: [{ to: runtimeConfig.paymentTokenAddress, data }, "latest"],
  });
  const [allowance] = allowanceInterface.decodeFunctionResult(
    "allowance",
    result,
  );
  return BigInt(allowance.toString());
}

export async function approveEntryFee(
  runtimeConfig: RuntimeConfig,
  amount: string,
): Promise<string> {
  const data = approveInterface.encodeFunctionData("approve", [
    runtimeConfig.paymentHandlerAddress,
    BigInt(amount),
  ]);
  return sendTransaction({
    runtimeConfig,
    to: runtimeConfig.paymentTokenAddress,
    data,
  });
}

export async function payEntryFee(args: {
  runtimeConfig: RuntimeConfig;
  amount: string;
  gameId: string;
  potentialReferrer: string;
}): Promise<string> {
  const data = playInterface.encodeFunctionData("play", [
    BigInt(args.amount),
    getPotentialReferrerAddress(args.potentialReferrer),
    deriveGameIdBytes32(args.gameId),
  ]);
  return sendTransaction({
    runtimeConfig: args.runtimeConfig,
    to: args.runtimeConfig.paymentAdapterAddress,
    data,
  });
}

export async function verifyPayment(args: {
  runtimeConfig: RuntimeConfig;
  authToken: string;
  txHash: string;
  gameId: string;
  amount: string;
}): Promise<VerifiedPayment> {
  const requestUrl = `${normalizeBaseUrl(args.runtimeConfig.authBaseUrl)}/payments/verify`;
  let response: Response;
  try {
    response = await fetch(requestUrl, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${args.authToken}`,
      },
      body: JSON.stringify({
        txHash: args.txHash,
        gameId: args.gameId,
        amount: args.amount,
      }),
    });
  } catch {
    const origin = new URL(requestUrl).origin;
    throw new Error(`Could not reach the auth server at ${origin}.`);
  }

  const responseBody = (await response.json().catch(() => ({}))) as
    | VerifiedPayment
    | { error?: string };

  if (!response.ok) {
    const errorCode =
      typeof responseBody === "object" &&
      responseBody !== null &&
      "error" in responseBody
        ? responseBody.error
        : undefined;

    switch (errorCode) {
      case "payment_not_confirmed":
        throw new Error(
          "Payment transaction found, but it is not confirmed yet. Wait for confirmations and try verify again.",
        );
      case "payment_not_found":
        throw new Error(
          "Payment transaction was not found yet. Wait for the transaction to mine, then verify again.",
        );
      case "payment_mismatch":
        throw new Error(
          "The payment proof did not match this wallet, room, or entry fee amount.",
        );
      case "not_implemented":
        throw new Error("Payment verification is not enabled on this auth server.");
      default:
        throw new Error(
          `Payment verification failed (${response.status}): ${JSON.stringify(responseBody)}`,
        );
    }
  }

  return responseBody as VerifiedPayment;
}

export function formatAllowanceStatus(
  allowance: bigint | null,
  requiredAmount: string,
): string {
  if (allowance === null) {
    return "Allowance not checked yet.";
  }

  const required = BigInt(requiredAmount);
  if (allowance >= required) {
    return `Allowance ready: ${allowance.toString()} approved for ${requiredAmount} required.`;
  }

  return `Allowance too low: ${allowance.toString()} approved for ${requiredAmount} required.`;
}

export function getPaymentActionErrorMessage(error: unknown): string {
  const message =
    getPaymentSpecificErrorMessage(error) ?? getWalletErrorMessage(error);
  return `Payment action failed: ${message}`;
}
