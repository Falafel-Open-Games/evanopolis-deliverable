import { useEffect, useMemo, useState } from "react";

import type { AuthSession } from "../lib/auth";
import {
  clearStoredEntryPayment,
  loadStoredEntryPayment,
  saveStoredEntryPayment,
} from "../lib/entry-payment-storage";
import {
  buildLaunchPayload,
  buildLaunchUrl,
  saveLaunchPayload,
} from "../lib/launch";
import {
  approveEntryFee,
  formatTokenAmount,
  getAllowance,
  getPaymentActionErrorMessage,
  getPotentialReferrerAddress,
  getTokenBalance,
  normalizeWalletAddress,
  payEntryFee,
  type VerifiedPayment,
  verifyPayment,
} from "../lib/payment";
import type { RuntimeConfig } from "../lib/runtime-config";

type JoinGamePanelProps = {
  title?: string;
  description: string;
  authSession: AuthSession | null;
  runtimeConfig: RuntimeConfig;
  gameId: string;
  entryFeeAmount: string;
  entryFeeLabel: string;
  playerCount?: number;
  creatorDisplayName?: string;
  referrerAddress?: string | null;
};

function shortenAddress(address: string): string {
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

function groupDigits(value: string): string {
  return value.replace(/\B(?=(\d{3})+(?!\d))/g, "_");
}

function getInitialStatusMessage(args: {
  authSession: AuthSession | null;
  referrerAddress: string | null;
  hasPaymentConfig: boolean;
}): string {
  if (args.authSession === null) {
    return "Connect your wallet first. Entry payment is required before launch.";
  }

  if (!args.hasPaymentConfig) {
    return "Payment contract configuration is missing for this environment.";
  }

  if (args.referrerAddress === null) {
    return "This join path does not include a creator wallet referral hint. Payment can continue without referral attribution.";
  }

  return "Approve the room entry fee allowance, submit the payment transaction, then verify it before launch.";
}

function getAllowanceSummary(
  allowance: bigint | null,
  requiredEntryFee: bigint,
  balance: bigint | null,
): string {
  if (balance !== null && balance < requiredEntryFee) {
    return "Wallet TRT balance is below the entry fee.";
  }

  if (allowance === null) {
    return "Check approval status when you are ready to continue.";
  }

  if (allowance >= requiredEntryFee) {
    return "Entry fee approved. You can continue to payment.";
  }

  return "Approval is still required before payment.";
}

export function JoinGamePanel({
  title = "Join Game",
  description,
  authSession,
  runtimeConfig,
  gameId,
  entryFeeAmount,
  entryFeeLabel,
  playerCount,
  creatorDisplayName,
  referrerAddress = null,
}: JoinGamePanelProps) {
  const normalizedReferrerAddress = useMemo(
    () =>
      referrerAddress === null ? null : normalizeWalletAddress(referrerAddress),
    [referrerAddress],
  );
  const hasPaymentConfig =
    runtimeConfig.paymentTokenAddress.trim().length > 0 &&
    runtimeConfig.paymentHandlerAddress.trim().length > 0 &&
    runtimeConfig.paymentAdapterAddress.trim().length > 0;
  const requiredEntryFee = BigInt(entryFeeAmount);
  const [allowance, setAllowance] = useState<bigint | null>(null);
  const [tokenBalance, setTokenBalance] = useState<bigint | null>(null);
  const [paymentTxHash, setPaymentTxHash] = useState<string>("");
  const [verifiedPayment, setVerifiedPayment] = useState<VerifiedPayment | null>(
    null,
  );
  const [statusMessage, setStatusMessage] = useState<string>(
    getInitialStatusMessage({
      authSession,
      referrerAddress: normalizedReferrerAddress,
      hasPaymentConfig,
    }),
  );
  const [isRefreshingAllowance, setIsRefreshingAllowance] =
    useState<boolean>(false);
  const [isApproving, setIsApproving] = useState<boolean>(false);
  const [isPaying, setIsPaying] = useState<boolean>(false);
  const [isVerifying, setIsVerifying] = useState<boolean>(false);
  const hasEnoughBalance =
    tokenBalance !== null && tokenBalance >= requiredEntryFee;
  const canPay =
    allowance !== null && allowance >= requiredEntryFee && hasEnoughBalance;
  const launchPayload =
    authSession === null
      ? null
      : buildLaunchPayload({
          runtimeConfig,
          token: authSession.token,
          gameId,
          playerAddress: authSession.address,
        });
  const referrerDisplay =
    normalizedReferrerAddress === null
      ? "Unavailable on this join path"
      : creatorDisplayName !== undefined && creatorDisplayName.trim().length > 0
        ? creatorDisplayName
        : shortenAddress(normalizedReferrerAddress);

  useEffect(() => {
    if (authSession === null) {
      setAllowance(null);
      setTokenBalance(null);
      setPaymentTxHash("");
      setVerifiedPayment(null);
      setStatusMessage(
        getInitialStatusMessage({
          authSession,
          referrerAddress: normalizedReferrerAddress,
          hasPaymentConfig,
        }),
      );
      return;
    }

    const storedPayment = loadStoredEntryPayment(gameId, authSession.address);
    setPaymentTxHash(storedPayment?.txHash ?? "");
    setVerifiedPayment(storedPayment?.verifiedPayment ?? null);
    setStatusMessage(
      storedPayment?.verifiedPayment !== null
        ? "A verified entry payment was restored for this room. Launch is ready."
        : storedPayment?.txHash
          ? "A saved payment transaction was restored for this room. Verify it to continue."
          : getInitialStatusMessage({
              authSession,
              referrerAddress: normalizedReferrerAddress,
              hasPaymentConfig,
            }),
    );
  }, [authSession, gameId, hasPaymentConfig, normalizedReferrerAddress]);

  useEffect(() => {
    if (authSession === null) {
      return;
    }

    if (paymentTxHash.length === 0 && verifiedPayment === null) {
      clearStoredEntryPayment(gameId, authSession.address);
      return;
    }

    saveStoredEntryPayment(gameId, authSession.address, {
      txHash: paymentTxHash,
      verifiedPayment,
    });
  }, [authSession, gameId, paymentTxHash, verifiedPayment]);

  useEffect(() => {
    if (authSession === null || !hasPaymentConfig) {
      return;
    }

    let cancelled = false;
    setIsRefreshingAllowance(true);

    void Promise.allSettled([
      getAllowance(runtimeConfig, authSession.address),
      getTokenBalance(runtimeConfig, authSession.address),
    ])
      .then(([allowanceResult, balanceResult]) => {
        if (cancelled) {
          return;
        }

        setAllowance(
          allowanceResult.status === "fulfilled" ? allowanceResult.value : null,
        );
        setTokenBalance(
          balanceResult.status === "fulfilled" ? balanceResult.value : null,
        );
      })
      .catch(() => {
        if (cancelled) {
          return;
        }

        setAllowance(null);
        setTokenBalance(null);
      })
      .finally(() => {
        if (cancelled) {
          return;
        }

        setIsRefreshingAllowance(false);
      });

    return () => {
      cancelled = true;
    };
  }, [authSession, hasPaymentConfig, runtimeConfig]);

  async function handleRefreshAllowance() {
    if (authSession === null) {
      return;
    }

    setIsRefreshingAllowance(true);
    setStatusMessage("Checking token allowance and TRT balance...");

    try {
      const [nextAllowance, nextBalance] = await Promise.all([
        getAllowance(runtimeConfig, authSession.address),
        getTokenBalance(runtimeConfig, authSession.address),
      ]);
      setAllowance(nextAllowance);
      setTokenBalance(nextBalance);
      setStatusMessage(
        getAllowanceSummary(nextAllowance, requiredEntryFee, nextBalance),
      );
    } catch (error) {
      setAllowance(null);
      setTokenBalance(null);
      setStatusMessage(getPaymentActionErrorMessage(error));
    } finally {
      setIsRefreshingAllowance(false);
    }
  }

  async function handleApproveEntryFee() {
    if (authSession === null) {
      return;
    }

    setIsApproving(true);
    setStatusMessage(`Requesting allowance approval for ${entryFeeLabel}...`);

    try {
      await approveEntryFee(runtimeConfig, entryFeeAmount);
      setPaymentTxHash("");
      setVerifiedPayment(null);
      setStatusMessage(
        `Approval submitted. Wait for wallet confirmation, then refresh the payment status.`,
      );
    } catch (error) {
      setStatusMessage(getPaymentActionErrorMessage(error));
    } finally {
      setIsApproving(false);
    }
  }

  async function handlePayEntryFee() {
    if (authSession === null) {
      return;
    }

    setIsPaying(true);
    setStatusMessage(`Submitting entry payment for room ${gameId}...`);

    try {
      const txHash = await payEntryFee({
        runtimeConfig,
        amount: entryFeeAmount,
        gameId,
        playerAddress: authSession.address,
        potentialReferrer: getPotentialReferrerAddress(
          normalizedReferrerAddress ?? "",
        ),
      });
      setPaymentTxHash(txHash);
      setVerifiedPayment(null);
      setStatusMessage(
        `Payment submitted. Verify it after the transaction is confirmed.`,
      );
    } catch (error) {
      setStatusMessage(getPaymentActionErrorMessage(error));
    } finally {
      setIsPaying(false);
    }
  }

  async function handleVerifyPayment() {
    if (authSession === null || paymentTxHash.trim().length === 0) {
      return;
    }

    setIsVerifying(true);
    setStatusMessage("Verifying payment proof with the auth server...");

    try {
      const verified = await verifyPayment({
        runtimeConfig,
        authToken: authSession.token,
        txHash: paymentTxHash.trim(),
        gameId,
        amount: entryFeeAmount,
      });
      setVerifiedPayment(verified);
      setStatusMessage(
        "Payment verified. You are ready to continue into the match.",
      );
    } catch (error) {
      setVerifiedPayment(null);
      setStatusMessage(
        error instanceof Error ? error.message : "Payment verification failed.",
      );
    } finally {
      setIsVerifying(false);
    }
  }

  function handleLaunch() {
    if (launchPayload === null) {
      return;
    }

    saveLaunchPayload(launchPayload);
    window.location.assign(buildLaunchUrl(launchPayload));
  }

  return (
    <div className="next-step-block">
      <p className="next-step-title">{title}</p>
      <p className="next-step-copy">{description}</p>
      <div className="result-block">
        <p>Match Summary</p>
        <code>
          {referrerDisplay}
          {playerCount !== undefined ? ` · ${playerCount} players` : ""}
          {` · ${entryFeeLabel}`}
        </code>
        <p className="field-note">
          Room code: <code title={gameId}>{gameId}</code>
          <span title={`On-chain amount: ${groupDigits(entryFeeAmount)}`}>
            {" "}
            · On-chain amount available on hover
          </span>
        </p>
      </div>
      <div className="result-block">
        <p>Payment Status</p>
        <code>{getAllowanceSummary(allowance, requiredEntryFee, tokenBalance)}</code>
        <p className="field-note">
          Wallet TRT balance:{" "}
          <code>
            {tokenBalance === null ? "Unavailable" : `${formatTokenAmount(tokenBalance)} TRT`}
          </code>
        </p>
      </div>
      {paymentTxHash.length > 0 ? (
        <p className="field-note">Payment submitted and ready to verify.</p>
      ) : null}
      <div className="button-row">
        <button
          type="button"
          disabled={authSession === null || !hasPaymentConfig || isApproving}
          onClick={() => void handleApproveEntryFee()}
        >
          {isApproving ? "Approving..." : "Approve Entry Fee"}
        </button>
        <button
          type="button"
          disabled={
            authSession === null ||
            !hasPaymentConfig ||
            isPaying ||
            !canPay
          }
          onClick={() => void handlePayEntryFee()}
        >
          {isPaying ? "Paying..." : "Pay Entry Fee"}
        </button>
      </div>
      <div className="button-row">
        <button
          type="button"
          disabled={authSession === null || !hasPaymentConfig || isRefreshingAllowance}
          onClick={() => void handleRefreshAllowance()}
        >
          {isRefreshingAllowance ? "Checking..." : "Refresh Payment State"}
        </button>
        <button
          type="button"
          disabled={
            authSession === null ||
            paymentTxHash.trim().length === 0 ||
            isVerifying
          }
          onClick={() => void handleVerifyPayment()}
        >
          {isVerifying ? "Verifying..." : "Verify Payment"}
        </button>
      </div>
      {verifiedPayment !== null ? (
        <>
          <div className="success-banner">
            <p className="success-title">Payment verified.</p>
            <p className="success-copy">
              This wallet is cleared for room entry and can continue into the
              match.
            </p>
          </div>
          <div className="button-row">
            <button type="button" onClick={handleLaunch}>
              Launch Game
            </button>
          </div>
          <p className="field-note">
            Continue into the embedded game client for this room.
          </p>
        </>
      ) : null}
      <p className="inline-note">{statusMessage}</p>
    </div>
  );
}
