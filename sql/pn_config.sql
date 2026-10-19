CREATE TABLE IF NOT EXISTS `pn_config` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `namespace` VARCHAR(64) NOT NULL,
  `key` VARCHAR(128) NOT NULL,
  `value` TEXT NOT NULL,
  `value_type` VARCHAR(16) NOT NULL DEFAULT 'string',
  `label` VARCHAR(255) NULL,
  `description` TEXT NULL,
  `requires_restart` TINYINT(1) NOT NULL DEFAULT 0,
  `convar` VARCHAR(128) NULL,
  `updated_by` VARCHAR(32) NOT NULL DEFAULT 'seed',
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `pn_config_ns_key` (`namespace`, `key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
