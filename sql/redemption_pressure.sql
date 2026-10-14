-- USDC redemption pressure, public layer (Ethereum mainnet).
-- One scan of token_transfers returns, per time bucket:
--   minted / burned      USDC issued and redeemed (Transfer from / to the zero address)
--   pool_net_<token>     net flow of each stablecoin into Curve 3pool (positive = into the pool)
--   usdc_to_usdt_*       rate implied by 3pool swaps that sold USDC for USDT
-- Parameters: @start, @end (TIMESTAMP), @hourly (BOOL: hourly buckets if true, daily if false)

DECLARE zero  STRING DEFAULT '0x0000000000000000000000000000000000000000';
DECLARE pool  STRING DEFAULT '0xbebc44782c7db0a1a60cb6fe97d0b483032ff1c7';  -- Curve 3pool
DECLARE usdc  STRING DEFAULT '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48';
DECLARE usdt  STRING DEFAULT '0xdac17f958d2ee523a2206206994597c13d831ec7';
DECLARE dai   STRING DEFAULT '0x6b175474e89094c44da98b954eedeac495271d0f';

WITH t AS (
  SELECT
    IF(@hourly, TIMESTAMP_TRUNC(block_timestamp, HOUR), TIMESTAMP_TRUNC(block_timestamp, DAY)) AS bucket,
    transaction_hash,
    token_address,
    from_address,
    to_address,
    CAST(value AS BIGNUMERIC) / IF(token_address = dai, 1e18, 1e6) AS amount
  FROM `bigquery-public-data.crypto_ethereum.token_transfers`
  WHERE block_timestamp >= @start AND block_timestamp < @end
    AND token_address IN (usdc, usdt, dai)
    AND (
      (token_address = usdc AND (from_address = zero OR to_address = zero))
      OR from_address = pool OR to_address = pool
    )
),

-- swaps that sold USDC into the pool and took USDT out, in the same transaction
swaps AS (
  SELECT
    bucket,
    transaction_hash,
    SUM(IF(token_address = usdc AND to_address = pool, amount, 0)) AS usdc_in,
    SUM(IF(token_address = usdt AND from_address = pool, amount, 0)) AS usdt_out
  FROM t
  WHERE from_address = pool OR to_address = pool
  GROUP BY bucket, transaction_hash
  -- drop multi-leg transactions (zaps, liquidity moves) whose ratio is not a swap price
  HAVING usdc_in > 1000 AND usdt_out > 0 AND usdt_out / usdc_in BETWEEN 0.5 AND 1.5
),

flows AS (
  SELECT
    bucket,
    SUM(IF(token_address = usdc AND from_address = zero, amount, 0)) AS minted,
    SUM(IF(token_address = usdc AND to_address = zero, amount, 0))   AS burned,
    SUM(IF(token_address = usdc AND to_address = pool, amount, 0)) - SUM(IF(token_address = usdc AND from_address = pool, amount, 0)) AS pool_net_usdc,
    SUM(IF(token_address = usdt AND to_address = pool, amount, 0)) - SUM(IF(token_address = usdt AND from_address = pool, amount, 0)) AS pool_net_usdt,
    SUM(IF(token_address = dai  AND to_address = pool, amount, 0)) - SUM(IF(token_address = dai  AND from_address = pool, amount, 0)) AS pool_net_dai
  FROM t
  GROUP BY bucket
)

SELECT
  f.bucket,
  ROUND(f.minted, 0) AS minted,
  ROUND(f.burned, 0) AS burned,
  ROUND(f.pool_net_usdc, 0) AS pool_net_usdc,
  ROUND(f.pool_net_usdt, 0) AS pool_net_usdt,
  ROUND(f.pool_net_dai, 0)  AS pool_net_dai,
  ROUND(APPROX_QUANTILES(SAFE_DIVIDE(s.usdt_out, s.usdc_in), 100)[SAFE_OFFSET(50)], 4) AS usdc_to_usdt_median,
  COUNT(s.transaction_hash) AS usdc_sell_swaps
FROM flows f
LEFT JOIN swaps s USING (bucket)
GROUP BY f.bucket, f.minted, f.burned, f.pool_net_usdc, f.pool_net_usdt, f.pool_net_dai
ORDER BY f.bucket
