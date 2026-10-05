-- S01 Opportunity Inventory
-- Recorded execution: https://dbfiddle.uk/Wt3hw9F8
-- Run the entire file in a fresh, disposable PostgreSQL 18 database.
-- The setup is a supplied fixture; this case covers the three read queries below.

-- SETUP: supplied synthetic-v1 fixture, as used in the recorded execution.
-- Synthetic fixtures only. Run in a fresh, disposable PostgreSQL database.
-- This script does not connect to any recruitment platform or send messages.
CREATE TABLE dg_lab_config (
  config_id integer PRIMARY KEY CHECK (config_id = 1),
  observation_end timestamptz NOT NULL,
  horizon_days integer NOT NULL CHECK (horizon_days > 0)
);
CREATE TABLE dg_companies (
  company_id text PRIMARY KEY,
  company_name text NOT NULL,
  niche text NOT NULL,
  employee_band text NOT NULL
);
CREATE TABLE dg_opportunities (
  opportunity_id text PRIMARY KEY,
  company_id text NOT NULL REFERENCES dg_companies(company_id),
  opportunity_type text NOT NULL CHECK (opportunity_type IN ('job', 'consulting')),
  role_title text NOT NULL,
  acquisition_route text NOT NULL CHECK (acquisition_route IN ('job_board', 'direct', 'referral')),
  work_mode text NOT NULL CHECK (work_mode IN ('remote', 'hybrid', 'onsite')),
  salary_min_gross_month_rmb numeric(12,2),
  salary_max_gross_month_rmb numeric(12,2),
  fit_score integer NOT NULL CHECK (fit_score BETWEEN 0 AND 100),
  qualification_status text NOT NULL CHECK (qualification_status IN ('qualified', 'review', 'rejected')),
  discovered_at timestamptz NOT NULL,
  source_url text NOT NULL,
  CHECK (salary_min_gross_month_rmb IS NULL OR salary_min_gross_month_rmb >= 0),
  CHECK (salary_max_gross_month_rmb IS NULL OR salary_max_gross_month_rmb >= 0),
  CHECK (salary_min_gross_month_rmb IS NULL OR salary_max_gross_month_rmb IS NULL
         OR salary_min_gross_month_rmb <= salary_max_gross_month_rmb),
  CHECK (opportunity_type = 'job' OR
         (salary_min_gross_month_rmb IS NULL AND salary_max_gross_month_rmb IS NULL))
);
CREATE TABLE dg_signals (
  signal_id text PRIMARY KEY,
  opportunity_id text NOT NULL REFERENCES dg_opportunities(opportunity_id),
  signal_type text NOT NULL,
  evidence_status text NOT NULL CHECK (evidence_status IN ('verified', 'unverified')),
  observed_at timestamptz NOT NULL,
  evidence_url text NOT NULL
);
CREATE TABLE dg_touches (
  touch_id text PRIMARY KEY,
  opportunity_id text NOT NULL REFERENCES dg_opportunities(opportunity_id),
  sent_at timestamptz NOT NULL,
  delivery_status text NOT NULL CHECK (delivery_status IN ('delivered', 'bounced', 'unknown')),
  delivered_at timestamptz,
  reply_status text NOT NULL CHECK (reply_status IN ('none', 'positive', 'negative')),
  replied_at timestamptz,
  CHECK ((delivery_status = 'delivered') = (delivered_at IS NOT NULL)),
  CHECK (delivered_at IS NULL OR delivered_at >= sent_at),
  CHECK ((reply_status = 'none') = (replied_at IS NULL)),
  CHECK (replied_at IS NULL OR replied_at >= sent_at)
);
CREATE TABLE dg_stage_events (
  event_id text PRIMARY KEY,
  source_event_key text NOT NULL,
  opportunity_id text NOT NULL REFERENCES dg_opportunities(opportunity_id),
  stage text NOT NULL CHECK (stage IN
    ('qualified', 'engaged', 'positive_reply', 'meeting', 'offer', 'closed_lost')),
  occurred_at timestamptz NOT NULL,
  ingested_at timestamptz NOT NULL CHECK (ingested_at >= occurred_at)
);
CREATE TABLE dg_payments (
  payment_id text PRIMARY KEY,
  opportunity_id text NOT NULL REFERENCES dg_opportunities(opportunity_id),
  paid_at timestamptz NOT NULL,
  collected_rmb numeric(12,2) NOT NULL CHECK (collected_rmb >= 0)
);
-- Transfer fixtures are separate from the career pipeline.
CREATE TABLE dg_demo_users (
  user_id text PRIMARY KEY,
  registered_at timestamptz,
  acquisition_source text NOT NULL
);
CREATE TABLE dg_demo_product_events (
  event_id text PRIMARY KEY,
  user_id text NOT NULL REFERENCES dg_demo_users(user_id),
  event_name text NOT NULL CHECK (event_name IN ('signup', 'activation', 'meaningful_use', 'error')),
  occurred_at timestamptz NOT NULL
);
CREATE TABLE dg_demo_assignments (
  user_id text PRIMARY KEY REFERENCES dg_demo_users(user_id),
  variant text NOT NULL CHECK (variant IN ('A', 'B')),
  assigned_at timestamptz NOT NULL
);
CREATE TABLE dg_demo_search_daily (
  search_date date NOT NULL,
  page_url text NOT NULL,
  clicks integer NOT NULL CHECK (clicks >= 0),
  impressions integer NOT NULL CHECK (impressions >= clicks),
  PRIMARY KEY(search_date, page_url)
);
CREATE TABLE dg_demo_geo_events (
  evidence_id text PRIMARY KEY,
  evidence_layer text NOT NULL CHECK (evidence_layer IN ('crawl', 'citation', 'referral', 'conversion')),
  observed_at timestamptz NOT NULL,
  evidence_ref text NOT NULL
);

-- All records and URLs are fabricated; this is a versioned test fixture, not market evidence.
INSERT INTO dg_lab_config (config_id, observation_end, horizon_days) VALUES
  (1, '2026-10-01 00:00:00+00', 14);

INSERT INTO dg_companies (company_id, company_name, niche, employee_band) VALUES
  ('C01', 'Example Atlas', 'AI SaaS', '11-50'),
  ('C02', 'Example Beacon', 'B2B SaaS', '51-200'),
  ('C03', 'Example Cedar', 'MarTech', '11-50'),
  ('C04', 'Example Drift', 'DTC', '51-200'),
  ('C05', 'Example Ember', 'AI SaaS', '1-10'),
  ('C06', 'Example Fjord', 'Industrial B2B', '11-50'),
  ('C07', 'Example Grove', 'B2B SaaS', '201-500'),
  ('C08', 'Example Haven', 'Agency', '11-50'),
  ('C09', 'Example Iris', 'Music technology', '1-10'),
  ('C10', 'Example Juniper', 'Education', '11-50');

INSERT INTO dg_opportunities (opportunity_id, company_id, opportunity_type, role_title, acquisition_route, work_mode, salary_min_gross_month_rmb, salary_max_gross_month_rmb, fit_score, qualification_status, discovered_at, source_url) VALUES
  ('O01', 'C01', 'job', 'Growth Engineer', 'direct', 'remote', 40000, 50000, 92, 'qualified', '2026-09-01 08:00:00+00', 'https://example.invalid/opportunities/O01'),
  ('O02', 'C02', 'job', 'Growth Lead', 'job_board', 'hybrid', 35000, 45000, 88, 'qualified', '2026-09-02 08:00:00+00', 'https://example.invalid/opportunities/O02'),
  ('O03', 'C03', 'job', 'MarTech Engineer', 'referral', 'remote', 30000, 40000, 90, 'qualified', '2026-09-03 08:00:00+00', 'https://example.invalid/opportunities/O03'),
  ('O04', 'C04', 'job', 'SEO Operations', 'job_board', 'onsite', 9000, 15000, 35, 'rejected', '2026-09-04 08:00:00+00', 'https://example.invalid/opportunities/O04'),
  ('O05', 'C05', 'job', 'Growth Engineer', 'direct', 'remote', 30000, 40000, 82, 'qualified', '2026-09-05 08:00:00+00', 'https://example.invalid/opportunities/O05'),
  ('O06', 'C06', 'job', 'SEO and GEO Lead', 'job_board', 'remote', 30000, 38000, 78, 'qualified', '2026-09-06 08:00:00+00', 'https://example.invalid/opportunities/O06'),
  ('O07', 'C07', 'job', 'Content Operations', 'job_board', 'hybrid', 12000, 18000, 40, 'rejected', '2026-09-07 08:00:00+00', 'https://example.invalid/opportunities/O07'),
  ('O08', 'C08', 'job', 'Growth Consultant', 'direct', 'remote', NULL, NULL, 75, 'review', '2026-09-08 08:00:00+00', 'https://example.invalid/opportunities/O08'),
  ('O09', 'C01', 'job', 'Technical SEO Lead', 'direct', 'remote', 32000, 42000, 85, 'qualified', '2026-09-09 08:00:00+00', 'https://example.invalid/opportunities/O09'),
  ('O10', 'C06', 'consulting', 'B2B Measurement Project', 'referral', 'remote', NULL, NULL, 87, 'qualified', '2026-09-10 08:00:00+00', 'https://example.invalid/opportunities/O10'),
  ('O11', 'C02', 'job', 'Growth Analytics Engineer', 'job_board', 'remote', 35000, 45000, 89, 'qualified', '2026-09-11 08:00:00+00', 'https://example.invalid/opportunities/O11'),
  ('O12', 'C08', 'consulting', 'GEO Audit Project', 'direct', 'remote', NULL, NULL, 72, 'review', '2026-09-12 08:00:00+00', 'https://example.invalid/opportunities/O12'),
  ('O13', 'C03', 'job', 'Growth Systems Engineer', 'direct', 'remote', 40000, 50000, 91, 'qualified', '2026-09-13 08:00:00+00', 'https://example.invalid/opportunities/O13'),
  ('O14', 'C07', 'job', 'Product Growth Engineer', 'referral', 'hybrid', 38000, 48000, 86, 'qualified', '2026-09-14 08:00:00+00', 'https://example.invalid/opportunities/O14'),
  ('O15', 'C05', 'job', 'Growth Engineer', 'direct', 'remote', 30000, 40000, 81, 'qualified', '2026-09-15 08:00:00+00', 'https://example.invalid/opportunities/O15'),
  ('O16', 'C04', 'job', 'Growth Data Engineer', 'job_board', 'remote', 30000, 40000, 80, 'qualified', '2026-09-23 08:00:00+00', 'https://example.invalid/opportunities/O16');

INSERT INTO dg_signals (signal_id, opportunity_id, signal_type, evidence_status, observed_at, evidence_url) VALUES
  ('S01', 'O01', 'active_hiring', 'verified', '2026-09-01 09:00:00+00', 'https://example.invalid/evidence/O01'),
  ('S02', 'O02', 'active_hiring', 'verified', '2026-09-02 09:00:00+00', 'https://example.invalid/evidence/O02'),
  ('S03', 'O03', 'active_hiring', 'verified', '2026-09-03 09:00:00+00', 'https://example.invalid/evidence/O03'),
  ('S04', 'O05', 'active_hiring', 'verified', '2026-09-05 09:00:00+00', 'https://example.invalid/evidence/O05'),
  ('S05', 'O06', 'active_hiring', 'verified', '2026-09-06 09:00:00+00', 'https://example.invalid/evidence/O06'),
  ('S06', 'O09', 'active_hiring', 'verified', '2026-09-09 09:00:00+00', 'https://example.invalid/evidence/O09'),
  ('S07', 'O10', 'active_hiring', 'verified', '2026-09-10 09:00:00+00', 'https://example.invalid/evidence/O10'),
  ('S08', 'O11', 'active_hiring', 'verified', '2026-09-11 09:00:00+00', 'https://example.invalid/evidence/O11'),
  ('S09', 'O13', 'active_hiring', 'verified', '2026-09-13 09:00:00+00', 'https://example.invalid/evidence/O13'),
  ('S10', 'O14', 'active_hiring', 'verified', '2026-09-14 09:00:00+00', 'https://example.invalid/evidence/O14'),
  ('S11', 'O15', 'active_hiring', 'verified', '2026-09-15 09:00:00+00', 'https://example.invalid/evidence/O15'),
  ('S12', 'O16', 'active_hiring', 'verified', '2026-09-23 09:00:00+00', 'https://example.invalid/evidence/O16'),
  ('S13', 'O01', 'analytics_migration', 'verified', '2026-09-01 10:00:00+00', 'https://example.invalid/evidence/S13'),
  ('S14', 'O01', 'market_expansion', 'unverified', '2026-09-01 11:00:00+00', 'https://example.invalid/evidence/S14'),
  ('S15', 'O08', 'active_hiring', 'unverified', '2026-09-08 09:00:00+00', 'https://example.invalid/evidence/S15');

INSERT INTO dg_touches (touch_id, opportunity_id, sent_at, delivery_status, delivered_at, reply_status, replied_at) VALUES
  ('T01', 'O01', '2026-09-02 10:00:00+00', 'delivered', '2026-09-02 10:05:00+00', 'positive', '2026-09-04 12:00:00+00'),
  ('T02', 'O01', '2026-09-03 10:00:00+00', 'delivered', '2026-09-03 10:05:00+00', 'none', NULL),
  ('T03', 'O02', '2026-09-03 10:00:00+00', 'delivered', '2026-09-03 10:05:00+00', 'positive', '2026-09-05 12:00:00+00'),
  ('T04', 'O03', '2026-09-04 10:00:00+00', 'delivered', '2026-09-04 10:05:00+00', 'positive', '2026-09-05 12:00:00+00'),
  ('T05', 'O05', '2026-09-06 10:00:00+00', 'delivered', '2026-09-06 10:05:00+00', 'none', NULL),
  ('T06', 'O05', '2026-09-12 10:00:00+00', 'delivered', '2026-09-12 10:05:00+00', 'none', NULL),
  ('T07', 'O06', '2026-09-07 10:00:00+00', 'delivered', '2026-09-07 10:05:00+00', 'negative', '2026-09-10 12:00:00+00'),
  ('T08', 'O09', '2026-09-10 10:00:00+00', 'bounced', NULL, 'none', NULL),
  ('T09', 'O10', '2026-09-11 10:00:00+00', 'delivered', '2026-09-11 10:05:00+00', 'positive', '2026-09-12 12:00:00+00'),
  ('T10', 'O11', '2026-09-12 10:00:00+00', 'delivered', '2026-09-12 10:05:00+00', 'positive', '2026-09-16 12:00:00+00'),
  ('T11', 'O13', '2026-09-14 10:00:00+00', 'delivered', '2026-09-14 10:05:00+00', 'positive', '2026-09-15 12:00:00+00'),
  ('T12', 'O14', '2026-09-15 10:00:00+00', 'delivered', '2026-09-15 10:05:00+00', 'positive', '2026-09-16 12:00:00+00'),
  ('T13', 'O15', '2026-09-16 10:00:00+00', 'unknown', NULL, 'none', NULL),
  ('T14', 'O16', '2026-09-24 10:00:00+00', 'delivered', '2026-09-24 10:05:00+00', 'positive', '2026-09-25 12:00:00+00');

INSERT INTO dg_stage_events (event_id, source_event_key, opportunity_id, stage, occurred_at, ingested_at) VALUES
  ('E001', 'O01:qualified', 'O01', 'qualified', '2026-09-01 12:00:00+00', '2026-09-01 12:05:00+00'),
  ('E002', 'O02:qualified', 'O02', 'qualified', '2026-09-02 12:00:00+00', '2026-09-02 12:05:00+00'),
  ('E003', 'O03:qualified', 'O03', 'qualified', '2026-09-03 12:00:00+00', '2026-09-03 12:05:00+00'),
  ('E004', 'O05:qualified', 'O05', 'qualified', '2026-09-05 12:00:00+00', '2026-09-05 12:05:00+00'),
  ('E005', 'O06:qualified', 'O06', 'qualified', '2026-09-06 12:00:00+00', '2026-09-06 12:05:00+00'),
  ('E006', 'O09:qualified', 'O09', 'qualified', '2026-09-09 12:00:00+00', '2026-09-09 12:05:00+00'),
  ('E007', 'O10:qualified', 'O10', 'qualified', '2026-09-10 12:00:00+00', '2026-09-10 12:05:00+00'),
  ('E008', 'O11:qualified', 'O11', 'qualified', '2026-09-11 12:00:00+00', '2026-09-11 12:05:00+00'),
  ('E009', 'O13:qualified', 'O13', 'qualified', '2026-09-13 12:00:00+00', '2026-09-13 12:05:00+00'),
  ('E010', 'O14:qualified', 'O14', 'qualified', '2026-09-14 12:00:00+00', '2026-09-14 12:05:00+00'),
  ('E011', 'O15:qualified', 'O15', 'qualified', '2026-09-15 12:00:00+00', '2026-09-15 12:05:00+00'),
  ('E012', 'O16:qualified', 'O16', 'qualified', '2026-09-23 12:00:00+00', '2026-09-23 12:05:00+00'),
  ('E013', 'O01:engaged', 'O01', 'engaged', '2026-09-02 10:00:00+00', '2026-09-02 10:05:00+00'),
  ('E014', 'O02:engaged', 'O02', 'engaged', '2026-09-03 10:00:00+00', '2026-09-03 10:05:00+00'),
  ('E015', 'O03:engaged', 'O03', 'engaged', '2026-09-04 10:00:00+00', '2026-09-04 10:05:00+00'),
  ('E016', 'O05:engaged', 'O05', 'engaged', '2026-09-06 10:00:00+00', '2026-09-06 10:05:00+00'),
  ('E017', 'O06:engaged', 'O06', 'engaged', '2026-09-07 10:00:00+00', '2026-09-07 10:05:00+00'),
  ('E018', 'O10:engaged', 'O10', 'engaged', '2026-09-11 10:00:00+00', '2026-09-11 10:05:00+00'),
  ('E019', 'O11:engaged', 'O11', 'engaged', '2026-09-12 10:00:00+00', '2026-09-12 10:05:00+00'),
  ('E020', 'O13:engaged', 'O13', 'engaged', '2026-09-14 10:00:00+00', '2026-09-14 10:05:00+00'),
  ('E021', 'O14:engaged', 'O14', 'engaged', '2026-09-15 10:00:00+00', '2026-09-15 10:05:00+00'),
  ('E022', 'O16:engaged', 'O16', 'engaged', '2026-09-24 10:00:00+00', '2026-09-24 10:05:00+00'),
  ('E023', 'O01:positive_reply', 'O01', 'positive_reply', '2026-09-04 12:00:00+00', '2026-09-04 12:05:00+00'),
  ('E024', 'O02:positive_reply', 'O02', 'positive_reply', '2026-09-05 12:00:00+00', '2026-09-05 12:05:00+00'),
  ('E025', 'O03:positive_reply', 'O03', 'positive_reply', '2026-09-05 12:00:00+00', '2026-09-05 12:05:00+00'),
  ('E026', 'O10:positive_reply', 'O10', 'positive_reply', '2026-09-12 12:00:00+00', '2026-09-12 12:05:00+00'),
  ('E027', 'O11:positive_reply', 'O11', 'positive_reply', '2026-09-16 12:00:00+00', '2026-09-16 12:05:00+00'),
  ('E028', 'O13:positive_reply', 'O13', 'positive_reply', '2026-09-15 12:00:00+00', '2026-09-15 12:05:00+00'),
  ('E029', 'O14:positive_reply', 'O14', 'positive_reply', '2026-09-16 12:00:00+00', '2026-09-16 12:05:00+00'),
  ('E030', 'O16:positive_reply', 'O16', 'positive_reply', '2026-09-25 12:00:00+00', '2026-09-25 12:05:00+00'),
  ('E031', 'O01:meeting', 'O01', 'meeting', '2026-09-06 15:00:00+00', '2026-09-06 15:05:00+00'),
  ('E032', 'O02:meeting', 'O02', 'meeting', '2026-09-20 15:00:00+00', '2026-09-20 15:05:00+00'),
  ('E033', 'O03:meeting', 'O03', 'meeting', '2026-09-06 15:00:00+00', '2026-09-06 15:05:00+00'),
  ('E034', 'O10:meeting', 'O10', 'meeting', '2026-09-14 15:00:00+00', '2026-09-14 15:05:00+00'),
  ('E035', 'O11:meeting', 'O11', 'meeting', '2026-09-19 15:00:00+00', '2026-09-19 15:05:00+00'),
  ('E036', 'O13:meeting', 'O13', 'meeting', '2026-09-13 15:00:00+00', '2026-09-13 15:05:00+00'),
  ('E037', 'O14:meeting', 'O14', 'meeting', '2026-09-18 15:00:00+00', '2026-09-18 15:05:00+00'),
  ('E038', 'O16:meeting', 'O16', 'meeting', '2026-09-26 15:00:00+00', '2026-09-26 15:05:00+00'),
  ('E039', 'O01:offer', 'O01', 'offer', '2026-09-12 15:00:00+00', '2026-09-12 15:05:00+00'),
  ('E040', 'O03:offer', 'O03', 'offer', '2026-09-14 15:00:00+00', '2026-09-14 15:05:00+00'),
  ('E041', 'O10:offer', 'O10', 'offer', '2026-09-20 15:00:00+00', '2026-09-20 15:05:00+00'),
  ('E042', 'O16:offer', 'O16', 'offer', '2026-09-29 15:00:00+00', '2026-09-29 15:05:00+00'),
  ('E043', 'O06:closed_lost', 'O06', 'closed_lost', '2026-09-11 15:00:00+00', '2026-09-11 15:05:00+00'),
  ('E044', 'O02:engaged', 'O02', 'engaged', '2026-09-03 10:00:00+00', '2026-09-03 10:10:00+00');

INSERT INTO dg_payments (payment_id, opportunity_id, paid_at, collected_rmb) VALUES
  ('P01', 'O10', '2026-09-25 08:00:00+00', 5000);

INSERT INTO dg_demo_users (user_id, registered_at, acquisition_source) VALUES
  ('U01', '2026-09-01 08:00:00+00', 'seo'),
  ('U02', '2026-09-02 08:00:00+00', 'paid'),
  ('U03', '2026-09-03 08:00:00+00', 'seo'),
  ('U04', '2026-09-28 08:00:00+00', 'referral'),
  ('U05', '2026-09-05 08:00:00+00', 'paid'),
  ('U06', NULL, 'referral');

INSERT INTO dg_demo_product_events (event_id, user_id, event_name, occurred_at) VALUES
  ('PE001', 'U01', 'signup', '2026-09-01 08:00:00+00'),
  ('PE002', 'U02', 'signup', '2026-09-02 08:00:00+00'),
  ('PE003', 'U03', 'signup', '2026-09-03 08:00:00+00'),
  ('PE004', 'U04', 'signup', '2026-09-28 08:00:00+00'),
  ('PE005', 'U05', 'signup', '2026-09-05 08:00:00+00'),
  ('PE006', 'U01', 'activation', '2026-09-02 09:00:00+00'),
  ('PE007', 'U02', 'activation', '2026-09-03 09:00:00+00'),
  ('PE008', 'U04', 'activation', '2026-09-28 09:00:00+00'),
  ('PE009', 'U01', 'meaningful_use', '2026-09-08 09:00:00+00'),
  ('PE010', 'U01', 'meaningful_use', '2026-09-08 09:10:00+00'),
  ('PE011', 'U02', 'meaningful_use', '2026-09-09 09:00:00+00'),
  ('PE012', 'U02', 'meaningful_use', '2026-09-09 09:10:00+00'),
  ('PE013', 'U01', 'meaningful_use', '2026-09-10 09:00:00+00'),
  ('PE014', 'U01', 'meaningful_use', '2026-09-10 09:10:00+00'),
  ('PE015', 'U03', 'meaningful_use', '2026-09-12 09:00:00+00'),
  ('PE016', 'U03', 'meaningful_use', '2026-09-12 09:10:00+00'),
  ('PE017', 'U04', 'meaningful_use', '2026-09-29 09:00:00+00'),
  ('PE018', 'U04', 'meaningful_use', '2026-09-29 09:10:00+00'),
  ('PE019', 'U01', 'meaningful_use', '2026-09-08 10:00:00+00'),
  ('PE020', 'U05', 'error', '2026-09-05 09:00:00+00');

INSERT INTO dg_demo_assignments (user_id, variant, assigned_at) VALUES
  ('U01', 'A', '2026-09-01 07:00:00+00'),
  ('U02', 'A', '2026-09-02 07:00:00+00'),
  ('U06', 'A', '2026-09-06 07:00:00+00'),
  ('U03', 'B', '2026-09-03 07:00:00+00'),
  ('U04', 'B', '2026-09-28 07:00:00+00'),
  ('U05', 'B', '2026-09-05 07:00:00+00');

INSERT INTO dg_demo_search_daily (search_date, page_url, clicks, impressions) VALUES
  ('2026-09-01', 'https://example.invalid/growth', 20, 200),
  ('2026-09-02', 'https://example.invalid/growth', 5, 100),
  ('2026-09-01', 'https://example.invalid/seo', 8, 400),
  ('2026-09-02', 'https://example.invalid/seo', 2, 100),
  ('2026-09-01', 'https://example.invalid/geo', 0, 10),
  ('2026-09-02', 'https://example.invalid/geo', 0, 0);

INSERT INTO dg_demo_geo_events (evidence_id, evidence_layer, observed_at, evidence_ref) VALUES
  ('G01', 'crawl', '2026-09-15 10:00:00+00', 'https://example.invalid/geo-evidence/1'),
  ('G02', 'crawl', '2026-09-15 10:00:00+00', 'https://example.invalid/geo-evidence/2'),
  ('G03', 'crawl', '2026-09-15 10:00:00+00', 'https://example.invalid/geo-evidence/3'),
  ('G04', 'crawl', '2026-09-15 10:00:00+00', 'https://example.invalid/geo-evidence/4'),
  ('G05', 'crawl', '2026-09-15 10:00:00+00', 'https://example.invalid/geo-evidence/5'),
  ('G06', 'citation', '2026-09-15 10:00:00+00', 'https://example.invalid/geo-evidence/6'),
  ('G07', 'citation', '2026-09-15 10:00:00+00', 'https://example.invalid/geo-evidence/7'),
  ('G08', 'referral', '2026-09-15 10:00:00+00', 'https://example.invalid/geo-evidence/8'),
  ('G09', 'referral', '2026-09-15 10:00:00+00', 'https://example.invalid/geo-evidence/9'),
  ('G10', 'referral', '2026-09-15 10:00:00+00', 'https://example.invalid/geo-evidence/10'),
  ('G11', 'conversion', '2026-09-15 10:00:00+00', 'https://example.invalid/geo-evidence/11');



-- Keep only facts available at the fixed observation boundary.
-- A source-event key identifies retransmission; event_id is the stable tie-breaker.
CREATE VIEW dg_clean_stage_events AS
SELECT event_id, source_event_key, opportunity_id, stage, occurred_at, ingested_at
FROM (
  SELECT e.*,
         ROW_NUMBER() OVER (
           PARTITION BY source_event_key ORDER BY ingested_at DESC, event_id DESC
         ) AS ingestion_rank
  FROM dg_stage_events e CROSS JOIN dg_lab_config c
  WHERE e.occurred_at < c.observation_end AND e.ingested_at < c.observation_end
) ranked
WHERE ingestion_rank = 1;

-- Ordered milestones, allowing intervening events. Anchor: first qualification.
-- All milestones must occur in [qualified_at, qualified_at + 14 days).
-- The view keeps immature cohorts but marks them; aggregate only mature rows.
CREATE VIEW dg_opportunity_funnel14 AS
WITH qualified AS (
  SELECT opportunity_id, MIN(occurred_at) AS qualified_at
  FROM dg_clean_stage_events WHERE stage = 'qualified' GROUP BY opportunity_id
), engaged AS (
  SELECT q.opportunity_id, q.qualified_at, MIN(e.occurred_at) AS engaged_at
  FROM qualified q LEFT JOIN dg_clean_stage_events e
    ON e.opportunity_id=q.opportunity_id AND e.stage='engaged'
   AND e.occurred_at >= q.qualified_at
   AND e.occurred_at < q.qualified_at + INTERVAL '14 days'
  GROUP BY q.opportunity_id,q.qualified_at
), replied AS (
  SELECT a.opportunity_id,a.qualified_at,a.engaged_at,MIN(e.occurred_at) AS replied_at
  FROM engaged a LEFT JOIN dg_clean_stage_events e
    ON e.opportunity_id=a.opportunity_id AND e.stage='positive_reply'
   AND e.occurred_at >= a.engaged_at
   AND e.occurred_at < a.qualified_at + INTERVAL '14 days'
  GROUP BY a.opportunity_id,a.qualified_at,a.engaged_at
), meetings AS (
  SELECT a.opportunity_id,a.qualified_at,a.engaged_at,a.replied_at,
         MIN(e.occurred_at) AS meeting_at
  FROM replied a LEFT JOIN dg_clean_stage_events e
    ON e.opportunity_id=a.opportunity_id AND e.stage='meeting'
   AND e.occurred_at >= a.replied_at
   AND e.occurred_at < a.qualified_at + INTERVAL '14 days'
  GROUP BY a.opportunity_id,a.qualified_at,a.engaged_at,a.replied_at
)
SELECT m.*,o.acquisition_route,o.opportunity_type,
       m.qualified_at + INTERVAL '14 days' <= c.observation_end AS is_mature
FROM meetings m
JOIN dg_opportunities o ON o.opportunity_id=m.opportunity_id
CROSS JOIN dg_lab_config c;

-- Q1: earliest five opportunities; display ID and title only.
SELECT opportunity_id, role_title
FROM dg_opportunities
ORDER BY discovered_at ASC, opportunity_id ASC
LIMIT 5;

-- Q2: earliest three opportunities; display four fields.
SELECT opportunity_id, role_title, acquisition_route, discovered_at
FROM dg_opportunities
ORDER BY discovered_at ASC, opportunity_id ASC
LIMIT 3;

-- Q3: earliest five opportunities; display four fields.
SELECT opportunity_id, role_title, acquisition_route, discovered_at
FROM dg_opportunities
ORDER BY discovered_at ASC, opportunity_id ASC
LIMIT 5;
