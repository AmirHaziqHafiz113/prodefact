/// Display helpers for ProDefact Tokens (1,000,000 Tokens = RM1). Balances
/// run into the hundreds of millions, so they are always grouped
/// ("125,840,000 Tokens"). Integer-only — never a floating-point balance.
library;

/// 1,000,000 Tokens = RM1 retail. Mirrors `TOKENS_PER_MYR` on the
/// backend (`functions/src/billing/tokens.ts`).
const kTokensPerMyr = 1000000;

/// `125840000` → `"125,840,000"`.
String formatTokenCount(int tokens) {
  final negative = tokens < 0;
  final digits = tokens.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buffer';
}

/// `125840000` → `"125,840,000 Tokens"` (`"1 Token"` for one).
String formatTokens(int tokens) =>
    '${formatTokenCount(tokens)} ${tokens == 1 ? 'Token' : 'Tokens'}';

/// The RM retail value of [tokens], e.g. `"RM125.84"` — for display only.
/// Amounts below one sen show as `"< RM0.01"` rather than `"RM0.00"`.
String tokensAsMyr(int tokens) {
  if (tokens <= 0) return 'RM0.00';
  if (tokens < kTokensPerMyr ~/ 100) return '< RM0.01';
  final sen = (tokens * 100) ~/ kTokensPerMyr;
  final ringgit = sen ~/ 100;
  final rem = (sen % 100).toString().padLeft(2, '0');
  return 'RM${formatTokenCount(ringgit)}.$rem';
}
