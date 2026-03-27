import { useEffect, useState } from "react";

import { signInWithWallet, type AuthSession } from "../lib/auth";
import type { RuntimeConfig } from "../lib/runtime-config";

export function useWalletSession(runtimeConfig: RuntimeConfig) {
  const [authSession, setAuthSession] = useState<AuthSession | null>(null);
  const [authStatusMessage, setAuthStatusMessage] = useState<string>(
    "Wallet not connected",
  );
  const [isConnectingWallet, setIsConnectingWallet] = useState<boolean>(false);

  function resetAuthSession(message: string) {
    setAuthSession(null);
    setIsConnectingWallet(false);
    setAuthStatusMessage(message);
  }

  async function handleConnectWallet() {
    setIsConnectingWallet(true);
    setAuthStatusMessage("Connecting wallet...");

    try {
      const session = await signInWithWallet(runtimeConfig);
      setAuthSession(session);
      setAuthStatusMessage("Wallet connected");
    } catch (error) {
      resetAuthSession(
        error instanceof Error ? error.message : "Wallet sign-in failed.",
      );
    } finally {
      setIsConnectingWallet(false);
    }
  }

  useEffect(() => {
    const provider = window.ethereum;
    if (provider?.on === undefined || provider.removeListener === undefined) {
      return;
    }

    function handleAccountsChanged() {
      resetAuthSession("Wallet account changed. Connect again.");
    }

    function handleChainChanged() {
      resetAuthSession("Wallet network changed. Connect again.");
    }

    provider.on("accountsChanged", handleAccountsChanged);
    provider.on("chainChanged", handleChainChanged);

    return () => {
      provider.removeListener?.("accountsChanged", handleAccountsChanged);
      provider.removeListener?.("chainChanged", handleChainChanged);
    };
  }, []);

  return {
    authSession,
    authStatusMessage,
    isConnectingWallet,
    handleConnectWallet,
  };
}
