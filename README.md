# USDC redemption pressure: the public layer

What public Ethereum data showed during the weekend Silicon Valley Bank failed (March 2023), and the same metrics for the last 90 days.

**Live page:** https://thalescb.github.io/usdc-redemption-monitor/

The FSB's October 2026 note on global stablecoin arrangements asks authorities to monitor secondary-market liquidity and redemptions. Both are public onchain. This project reads three of them from Ethereum mainnet:

| Metric | How it's measured |
|---|---|
| Net USDC issuance | USDC transfers from and to the zero address (mints and burns) |
| Net USDT flow into Curve 3pool | USDT transfers into and out of `0xbebc44782c7db0a1a60cb6fe97d0b483032ff1c7` |
| USDC → USDT swap price | Per transaction, USDT out of the pool over USDC in, for sells above 1,000 USDC; ratios outside 0.5–1.5 dropped as multi-leg routes; median per period |

## What the SVB weekend shows

- From 17:00 to 22:00 UTC on 10 March 2023, $121M of USDT left the pool while the median swap price held at or above $0.9992. The low came the next morning: $0.8807 at 07:00 UTC.
- Swaps ran all weekend. Minting fell to $75.8M over Saturday and Sunday, against $1.0B on the Friday, and large burns resumed on Monday from 12:00 UTC.
- The price jumped at 22:00 UTC on Sunday, the evening US authorities announced that all SVB deposits would be covered.

## Limits

- Ethereum only. USDC on other chains isn't included.
- Pool flows include liquidity adds and removals, not only swaps.
- Holder location and the reserves themselves are off-chain. This is the public half of the picture; the other half needs issuer reporting.

## Reproduce

Data comes from Google's public dataset `bigquery-public-data.crypto_ethereum.token_transfers`. With the Google Cloud SDK installed:

```powershell
./build.ps1 -Project <your-gcp-project>      # query + build (~75 GB scanned)
./build.ps1 -Project x -SkipQuery            # rebuild the page from the CSVs in data/
```

The query is in [`sql/redemption_pressure.sql`](sql/redemption_pressure.sql). The page is a single static file with no dependencies.

Thales Barbosa
