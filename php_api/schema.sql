CREATE DATABASE IF NOT EXISTS ybs_ai
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE ybs_ai;

CREATE TABLE IF NOT EXISTS notifications (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  title VARCHAR(160) NOT NULL,
  message TEXT NOT NULL,
  type ENUM('info', 'update', 'alert') NOT NULL DEFAULT 'info',
  is_published TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  INDEX idx_notifications_published_created (is_published, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS feedback (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  type ENUM('bug', 'wrong_info', 'suggestion', 'other') NOT NULL,
  message TEXT NOT NULL,
  route_id VARCHAR(80) NULL,
  user_id VARCHAR(120) NULL,
  ip_hash CHAR(64) NOT NULL,
  status ENUM('new', 'reviewing', 'resolved', 'rejected') NOT NULL DEFAULT 'new',
  admin_note TEXT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  INDEX idx_feedback_ip_created (ip_hash, created_at),
  INDEX idx_feedback_status_created (status, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create a dedicated DB user in production, not the root user.
-- Replace the password before running this section.
-- CREATE USER 'ybs_api'@'localhost' IDENTIFIED BY 'CHANGE_THIS_LONG_PASSWORD';
-- GRANT SELECT, INSERT ON ybs_ai.notifications TO 'ybs_api'@'localhost';
-- GRANT SELECT, INSERT ON ybs_ai.feedback TO 'ybs_api'@'localhost';
-- FLUSH PRIVILEGES;
