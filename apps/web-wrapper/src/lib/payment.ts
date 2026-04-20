import { Interface, formatUnits, getAddress, keccak256, toUtf8Bytes } from "ethers";

import { ensureWalletOnExpectedChain } from "./auth";
import type { RuntimeConfig } from "./runtime-config";

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

type TransactionRequest = {
  from: string;
  to: string;
  data: string;
};

const allowanceInterface = new Interface([
  "function allowance(address owner, address spender) view returns (uint256)",
]);
const balanceInterface = new Interface([
  "function balanceOf(address owner) view returns (uint256)",
]);
const approveInterface = new Interface([
  "function approve(address spender, uint256 amount)",
]);
const playInterface = new Interface([
  "function play(uint256 amount, address potentialReferrer, bytes32 gameId)",
]);
const revertInterface = new Interface([
  "error Error(string)",
  "error Panic(uint256)",
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

function normalizeBaseUrl(url: string): string {
  return url.trim().replace(/\/$/, "");
}

function getWalletErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }

  if (
    typeof error === "object" &&
    error !== null &&
    "data" in error &&
    typeof error.data === "object" &&
    error.data !== null &&
    "message" in error.data &&
    typeof error.data.message === "string"
  ) {
    return error.data.message;
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

function getWalletErrorData(error: unknown): string | null {
  if (typeof error !== "object" || error === null) {
    return null;
  }

  const walletError = error as {
    data?: unknown;
    error?: { data?: unknown };
  };
  const directNestedData =
    typeof walletError.data === "object" &&
    walletError.data !== null &&
    "data" in walletError.data
      ? walletError.data.data
      : undefined;
  const nestedData =
    typeof walletError.error === "object" &&
    walletError.error !== null &&
    "data" in walletError.error
      ? walletError.error.data
      : undefined;
  const data = directNestedData ?? walletError.data ?? nestedData;
  return typeof data === "string" ? data : null;
}

function getPreflightErrorMessage(error: unknown): string {
  const revertData = getWalletErrorData(error);
  if (revertData !== null) {
    try {
      const parsed = revertInterface.parseError(revertData);
      if (parsed?.name === "Error") {
        const reason = parsed.args[0];
        if (typeof reason === "string" && reason.length > 0) {
          return reason;
        }
      }

      if (parsed?.name === "Panic") {
        return `Contract panic (${parsed.args[0].toString()}).`;
      }
    } catch {
      // Fall through to the wallet error message when the revert payload is
      // not one of the standard Solidity error encodings.
    }
  }

  return getWalletErrorMessage(error);
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

export function getEffectivePotentialReferrerAddress(args: {
  playerAddress: string;
  referrerAddress: string;
}): string {
  const playerAddress = normalizeWalletAddress(args.playerAddress);
  const referrerAddress = normalizeWalletAddress(args.referrerAddress);

  if (playerAddress === null || referrerAddress === null) {
    return ZERO_ADDRESS;
  }

  if (playerAddress.toLowerCase() === referrerAddress.toLowerCase()) {
    return ZERO_ADDRESS;
  }

  return referrerAddress;
}

async function assertTransactionWillSucceed(
  provider: EthereumProvider,
  transaction: TransactionRequest,
): Promise<void> {
  try {
    await provider.request<string>({
      method: "eth_call",
      params: [transaction, "latest"],
    });
  } catch (error) {
    throw new Error(getPreflightErrorMessage(error));
  }
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

  // Let the injected wallet own gas and fee estimation. Preloading gas fields
  // here can produce unusable values when the wallet's active RPC is stale or
  // otherwise disagrees with the network.
  const transaction: TransactionRequest = {
    from,
    to: args.to,
    data: args.data,
  };

  await assertTransactionWillSucceed(provider, transaction);

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

export async function getTokenBalance(
  runtimeConfig: RuntimeConfig,
  ownerAddress: string,
): Promise<bigint> {
  const provider = getEthereumProvider();
  const data = balanceInterface.encodeFunctionData("balanceOf", [ownerAddress]);
  const result = await provider.request<string>({
    method: "eth_call",
    params: [{ to: runtimeConfig.paymentTokenAddress, data }, "latest"],
  });
  const [balance] = balanceInterface.decodeFunctionResult("balanceOf", result);
  return BigInt(balance.toString());
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
  playerAddress: string;
}): Promise<string> {
  const data = playInterface.encodeFunctionData("play", [
    BigInt(args.amount),
    getEffectivePotentialReferrerAddress({
      playerAddress: args.playerAddress,
      referrerAddress: args.potentialReferrer,
    }),
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

export function formatTokenAmount(amount: bigint, decimals: number = 18): string {
  const formatted = formatUnits(amount, decimals);
  if (!formatted.includes(".")) {
    return formatted;
  }

  return formatted.replace(/\.?0+$/, "");
}

export function getPaymentActionErrorMessage(error: unknown): string {
  const message =
    getPaymentSpecificErrorMessage(error) ?? getWalletErrorMessage(error);
  return `Payment action failed: ${message}`;
}
