-- ============================================================
-- FlavorFlow Restaurant DB Schema
-- Import this in phpMyAdmin (XAMPP)
-- ============================================================

CREATE DATABASE IF NOT EXISTS restaurant_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE restaurant_db;

-- ─── CATEGORIES ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS categories (
  id   INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE
);

-- ─── PRODUCTS ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS products (
  id           VARCHAR(36)    PRIMARY KEY,
  name         VARCHAR(255)   NOT NULL,
  price        DECIMAL(10,2)  NOT NULL,
  category     VARCHAR(100)   DEFAULT '',
  description  TEXT           DEFAULT '',
  image_url    TEXT           DEFAULT '',
  is_available TINYINT(1)     DEFAULT 1,
  quantity     INT            DEFAULT 0,
  created_at   TIMESTAMP      DEFAULT CURRENT_TIMESTAMP
);

-- ─── TABLES ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tables (
  table_no VARCHAR(20) PRIMARY KEY,
  label    VARCHAR(50) DEFAULT '',
  status   ENUM('FREE','RUNNING') DEFAULT 'FREE'
);

-- Seed default 12 tables
INSERT IGNORE INTO tables (table_no, label) VALUES
  ('T1','Table 1'),('T2','Table 2'),('T3','Table 3'),
  ('T4','Table 4'),('T5','Table 5'),('T6','Table 6'),
  ('T7','Table 7'),('T8','Table 8'),('T9','Table 9'),
  ('T10','Table 10'),('T11','Table 11'),('T12','Table 12'),
  ('TAKEAWAY','Takeaway');

-- ─── ACTIVE ORDERS ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS table_orders (
  id          VARCHAR(36) PRIMARY KEY,
  table_no    VARCHAR(20) NOT NULL,
  status      ENUM('sentToKitchen','open','billed') DEFAULT 'sentToKitchen',
  is_takeaway TINYINT(1)  DEFAULT 0,
  items       JSON        NOT NULL,
  updated_at  TIMESTAMP   DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  created_at  TIMESTAMP   DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (table_no) REFERENCES tables(table_no)
);

-- ─── INVOICES ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS invoices (
  id           VARCHAR(36)   PRIMARY KEY,
  device_id    VARCHAR(100)  DEFAULT '',
  date         DATETIME      NOT NULL,
  total        DECIMAL(10,2) NOT NULL,
  payment_mode VARCHAR(50)   DEFAULT 'Cash',
  table_no     VARCHAR(20)   DEFAULT '',
  items        JSON,
  created_at   TIMESTAMP     DEFAULT CURRENT_TIMESTAMP
);

-- ─── CUSTOMER WEB ORDERS ────────────────────────────────────
CREATE TABLE IF NOT EXISTS customer_orders (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  table_no   VARCHAR(20) NOT NULL,
  items      JSON        NOT NULL,
  note       TEXT        DEFAULT '',
  status     ENUM('pending','accepted','done') DEFAULT 'pending',
  created_at TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
);

-- ─── APP SETTINGS ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS settings (
  key_name  VARCHAR(100) PRIMARY KEY,
  value     TEXT
);

INSERT IGNORE INTO settings (key_name, value) VALUES
  ('restaurant_name', 'FlavorFlow Restaurant'),
  ('table_count', '12'),
  ('gst_percent', '5');
