import type { RuntimeConfig } from "./runtime-config";

export type AuthSession = {
  address: string;
  token: string;
  expiresAt: string;
  chainId: string;
};

type ChallengeResponse = {
  nonce: string;
  message: string;
  expires_at: string;
};

type VerifyResponse = {
  token: string;
  expires_at: string;
};

type ChainParams = {
  chainId: string;
  chainName: string;
  nativeCurrency: {
    name: string;
    symbol: string;
    decimals: number;
  };
  rpcUrls: string[];
  blockExplorerUrls: string[];
};

const CHAIN_PRESETS: Record<string, Omit<ChainParams, "chainId">> = {
  "42161": {
    chainName: "Arbitrum One",
    nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
    rpcUrls: ["https://arb1.arbitrum.io/rpc"],
    blockExplorerUrls: ["https://arbiscan.io"],
  },
  "421614": {
    chainName: "Arbitrum Sepolia",
    nativeCurrency: {
      name: "Arbitrum Sepolia Ether",
      symbol: "ETH",
      decimals: 18,
    },
    rpcUrls: ["https://sepolia-rollup.arbitrum.io/rpc"],
    blockExplorerUrls: ["https://sepolia.arbiscan.io"],
  },
};

function normalizeBaseUrl(url: string): string {
  return url.trim().replace(/\/$/, "");
}

function getChainHex(chainId: string): string {
  return `0x${Number(chainId).toString(16)}`;
}

function getChainParams(chainId: string): ChainParams | null {
  const preset = CHAIN_PRESETS[chainId];
  if (preset === undefined) {
    return null;
  }

  return {
    chainId: getChainHex(chainId),
    ...preset,
  };
}

function getWalletErrorCode(error: unknown): number | undefined {
  if (typeof error !== "object" || error === null) {
    return undefined;
  }

  const walletError = error as {
    code?: number;
    data?: { originalError?: { code?: number }; code?: number };
  };
  return (
    walletError.code ??
    walletError.data?.originalError?.code ??
    walletError.data?.code
  );
}

function getWalletErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    return error.message;
  }

  return String(error);
}

function getEthereumProvider(): EthereumProvider {
  if (window.ethereum === undefined) {
    throw new Error(
      "No injected wallet found. Open Evanopolis in a wallet-enabled browser.",
    );
  }

  return window.ethereum;
}

async function fetchJson<T>(url: string, init: RequestInit): Promise<T> {
  let response: Response;
  try {
    response = await fetch(url, init);
  } catch {
    const requestUrl = new URL(url);
    throw new Error(
      `Could not reach the auth server at ${requestUrl.origin}.`,
    );
  }

  if (response.ok) {
    return (await response.json()) as T;
  }

  const errorBody = await response.json().catch(() => ({}));
  if (
    typeof errorBody === "object" &&
    errorBody !== null &&
    "error" in errorBody &&
    errorBody.error === "origin_not_allowed"
  ) {
    throw new Error(
      `This page origin is not allowed by the auth server. Add ${window.location.origin} to the allowed origins list.`,
    );
  }

  throw new Error(
    `Request failed (${response.status}): ${JSON.stringify(errorBody)}`,
  );
}

async function ensureExpectedChain(
  provider: EthereumProvider,
  expectedChainId: string,
): Promise<void> {
  const currentChainId = await provider.request<string>({
    method: "eth_chainId",
  });
  const expectedChainHex = getChainHex(expectedChainId);

  if (currentChainId.toLowerCase() === expectedChainHex.toLowerCase()) {
    return;
  }

  try {
    await provider.request({
      method: "wallet_switchEthereumChain",
      params: [{ chainId: expectedChainHex }],
    });
    return;
  } catch (error) {
    const errorCode = getWalletErrorCode(error);
    if (errorCode === 4902) {
      const chainParams = getChainParams(expectedChainId);
      if (chainParams === null) {
        throw new Error(
          `Expected chain ${expectedChainId} is not available in the wrapper presets.`,
        );
      }

      await provider.request({
        method: "wallet_addEthereumChain",
        params: [chainParams],
      });
      await provider.request({
        method: "wallet_switchEthereumChain",
        params: [{ chainId: expectedChainHex }],
      });
      return;
    }

    if (errorCode === 4001) {
      throw new Error("Network switch was cancelled in the wallet.");
    }

    throw new Error(
      `Failed to switch to chain ${expectedChainId}: ${getWalletErrorMessage(error)}`,
    );
  }
}

export async function ensureWalletOnExpectedChain(
  runtimeConfig: RuntimeConfig,
): Promise<void> {
  const provider = getEthereumProvider();
  await ensureExpectedChain(provider, runtimeConfig.expectedChainId);
}

export async function signInWithWallet(
  runtimeConfig: RuntimeConfig,
): Promise<AuthSession> {
  const provider = getEthereumProvider();
  const accounts = await provider.request<string[]>({
    method: "eth_requestAccounts",
  });
  const address = accounts[0];

  if (typeof address !== "string" || address.length === 0) {
    throw new Error("The wallet did not return an account.");
  }

  await ensureExpectedChain(provider, runtimeConfig.expectedChainId);

  const authBaseUrl = normalizeBaseUrl(runtimeConfig.authBaseUrl);
  const challenge = await fetchJson<ChallengeResponse>(
    `${authBaseUrl}/auth/challenge`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        address,
        chainId: Number(runtimeConfig.expectedChainId),
        origin: window.location.origin,
      }),
    },
  );

  const signature = await provider.request<string>({
    method: "personal_sign",
    params: [challenge.message, address],
  });

  const verify = await fetchJson<VerifyResponse>(`${authBaseUrl}/auth/verify`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      address,
      nonce: challenge.nonce,
      signature,
    }),
  });

  return {
    address,
    token: verify.token,
    expiresAt: verify.expires_at,
    chainId: runtimeConfig.expectedChainId,
  };
}
