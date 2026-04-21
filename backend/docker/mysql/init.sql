CREATE TABLE IF NOT EXISTS checkout_sessions (
  id VARCHAR(191) NOT NULL,
  provider VARCHAR(32) NOT NULL DEFAULT 'lemon',
  installation_id VARCHAR(191) NOT NULL,
  customer_email VARCHAR(320) DEFAULT NULL,
  source VARCHAR(32) NOT NULL,
  app_version VARCHAR(32) DEFAULT NULL,
  status VARCHAR(32) NOT NULL,
  lemon_checkout_id VARCHAR(191) DEFAULT NULL,
  lemon_checkout_url TEXT DEFAULT NULL,
  checkout_id VARCHAR(191) DEFAULT NULL,
  checkout_url TEXT DEFAULT NULL,
  license_key VARCHAR(191) DEFAULT NULL,
  order_id VARCHAR(191) DEFAULT NULL,
  order_identifier VARCHAR(191) DEFAULT NULL,
  order_amount BIGINT DEFAULT NULL,
  order_currency VARCHAR(16) NOT NULL DEFAULT 'KRW',
  payment_key VARCHAR(191) DEFAULT NULL,
  payment_method VARCHAR(64) DEFAULT NULL,
  payment_status VARCHAR(64) DEFAULT NULL,
  store_id BIGINT DEFAULT NULL,
  product_id BIGINT DEFAULT NULL,
  variant_id BIGINT DEFAULT NULL,
  created_at VARCHAR(32) NOT NULL,
  updated_at VARCHAR(32) NOT NULL,
  expires_at VARCHAR(32) NOT NULL,
  completed_at VARCHAR(32) DEFAULT NULL,
  claimed_at VARCHAR(32) DEFAULT NULL,
  last_error TEXT DEFAULT NULL,
  PRIMARY KEY (id),
  KEY idx_checkout_sessions_installation (installation_id),
  KEY idx_checkout_sessions_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS webhook_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  event_name VARCHAR(191) NOT NULL,
  resource_type VARCHAR(191) DEFAULT NULL,
  resource_id VARCHAR(191) DEFAULT NULL,
  status VARCHAR(32) NOT NULL,
  error_message TEXT DEFAULT NULL,
  payload_json LONGTEXT NOT NULL,
  received_at VARCHAR(32) NOT NULL,
  processed_at VARCHAR(32) DEFAULT NULL,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS licenses (
  license_key VARCHAR(191) NOT NULL,
  provider VARCHAR(32) NOT NULL,
  customer_email VARCHAR(320) DEFAULT NULL,
  status VARCHAR(32) NOT NULL,
  activation_limit INT NOT NULL,
  order_id VARCHAR(191) DEFAULT NULL,
  created_at VARCHAR(32) NOT NULL,
  updated_at VARCHAR(32) NOT NULL,
  PRIMARY KEY (license_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS license_instances (
  id VARCHAR(191) NOT NULL,
  license_key VARCHAR(191) NOT NULL,
  installation_id VARCHAR(191) NOT NULL,
  instance_name VARCHAR(120) NOT NULL,
  status VARCHAR(32) NOT NULL,
  created_at VARCHAR(32) NOT NULL,
  updated_at VARCHAR(32) NOT NULL,
  deactivated_at VARCHAR(32) DEFAULT NULL,
  last_validated_at VARCHAR(32) DEFAULT NULL,
  PRIMARY KEY (id),
  KEY idx_license_instances_license_key (license_key),
  KEY idx_license_instances_installation (installation_id),
  CONSTRAINT fk_license_instances_license_key
    FOREIGN KEY (license_key) REFERENCES licenses (license_key)
    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
