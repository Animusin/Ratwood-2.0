-- Apply to the GAME database before enabling SUPPORTER_HOUSING.
-- If sql_table_prefix is configured, prefix the table name accordingly.
-- A single InnoDB statement atomically replaces each bounded decor snapshot.
CREATE TABLE IF NOT EXISTS `supporter_housing` (
  `ckey` varchar(32) NOT NULL,
  `revision` int unsigned NOT NULL DEFAULT 1,
  `decor` text NOT NULL,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`ckey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
