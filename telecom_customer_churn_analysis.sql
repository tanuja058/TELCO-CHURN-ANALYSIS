/*
PROJECT: Telecom Customer Churn Analysis
*/

-- =========================================================
-- 01. DATABASE SETUP
-- =========================================================

CREATE DATABASE IF NOT EXISTS telecom_churn;
USE telecom_churn;

-- Confirm that the raw table exists and inspect its structure.
SHOW TABLES;
DESCRIBE customerchurn_raw;

-- Preview records and check the dataset size.
SELECT *
FROM customerchurn_raw
LIMIT 10;

SELECT COUNT(*) AS total_raw_records
FROM customerchurn_raw;


-- =========================================================
-- 02. BACKUP THE RAW DATA
-- =========================================================

CREATE TABLE IF NOT EXISTS customerchurn_backup
LIKE customerchurn_raw;

-- Insert only if the backup table is empty, to avoid duplicate
-- inserts when the script is rerun.
INSERT INTO customerchurn_backup
SELECT *
FROM customerchurn_raw
WHERE NOT EXISTS (
    SELECT 1
    FROM (
        SELECT COUNT(*) AS backup_count
        FROM customerchurn_backup
    ) AS b
    WHERE b.backup_count > 0
);

SELECT COUNT(*) AS backup_records
FROM customerchurn_backup;


-- =========================================================
-- 03. DATA QUALITY CHECKS
-- =========================================================

-- 3.1 Check duplicate customer IDs.
SELECT
    customerID,
    COUNT(*) AS duplicate_count
FROM customerchurn_raw
GROUP BY customerID
HAVING COUNT(*) > 1;

-- 3.2 Count missing or blank values in important columns.
SELECT
    COUNT(*) AS total_records,
    SUM(customerID IS NULL OR TRIM(CAST(customerID AS CHAR)) = '') AS missing_customerID,
    SUM(gender IS NULL OR TRIM(CAST(gender AS CHAR)) = '') AS missing_gender,
    SUM(TotalCharges IS NULL OR TRIM(CAST(TotalCharges AS CHAR)) = '') AS missing_totalcharges,
    SUM(MonthlyCharges IS NULL) AS missing_monthlycharges,
    SUM(Churn IS NULL OR TRIM(CAST(Churn AS CHAR)) = '') AS missing_churn
FROM customerchurn_raw;

-- 3.3 Inspect the 11 blank TotalCharges records.
SELECT
    customerID,
    tenure,
    TotalCharges,
    Churn
FROM customerchurn_raw
WHERE TotalCharges IS NULL
   OR TRIM(CAST(TotalCharges AS CHAR)) = '';

-- 3.4 Check distinct categorical values.
SELECT DISTINCT gender FROM customerchurn_raw;
SELECT DISTINCT InternetService FROM customerchurn_raw;
SELECT DISTINCT Contract FROM customerchurn_raw;
SELECT DISTINCT PaymentMethod FROM customerchurn_raw;
SELECT DISTINCT Churn FROM customerchurn_raw;

SELECT DISTINCT OnlineBackup FROM customerchurn_raw;
SELECT DISTINCT OnlineSecurity FROM customerchurn_raw;
SELECT DISTINCT DeviceProtection FROM customerchurn_raw;
SELECT DISTINCT TechSupport FROM customerchurn_raw;
SELECT DISTINCT PaperlessBilling FROM customerchurn_raw;
SELECT DISTINCT StreamingMovies FROM customerchurn_raw;
SELECT DISTINCT StreamingTV FROM customerchurn_raw;

-- 3.5 Check numeric ranges.
SELECT *
FROM customerchurn_raw
WHERE CAST(tenure AS SIGNED) < 0
   OR CAST(MonthlyCharges AS DECIMAL(10,2)) < 0
   OR CAST(numAdminTickets AS SIGNED) < 0
   OR CAST(numTechTickets AS SIGNED) < 0;

-- 3.6 Check whether TotalCharges contains non-numeric values.
-- Blank values are excluded because they are handled separately.
SELECT
    customerID,
    TotalCharges
FROM customerchurn_raw
WHERE NULLIF(TRIM(CAST(TotalCharges AS CHAR)), '') IS NOT NULL
  AND TRIM(CAST(TotalCharges AS CHAR)) NOT REGEXP '^[0-9]+([.][0-9]+)?$';


-- =========================================================
-- 04. CREATE THE CLEANED TABLE
-- =========================================================

DROP TABLE IF EXISTS customerchurn_cleaned;

CREATE TABLE customerchurn_cleaned AS
SELECT
    TRIM(CAST(customerID AS CHAR)) AS customerID,

    CONCAT(
        UPPER(LEFT(LOWER(TRIM(gender)), 1)),
        SUBSTRING(LOWER(TRIM(gender)), 2)
    ) AS gender,

    CAST(SeniorCitizen AS UNSIGNED) AS SeniorCitizen,

    TRIM(Partner) AS Partner,
    TRIM(Dependents) AS Dependents,
    CAST(tenure AS UNSIGNED) AS tenure,

    TRIM(PhoneService) AS PhoneService,
    TRIM(MultipleLines) AS MultipleLines,
    TRIM(InternetService) AS InternetService,
    TRIM(OnlineSecurity) AS OnlineSecurity,
    TRIM(OnlineBackup) AS OnlineBackup,
    TRIM(DeviceProtection) AS DeviceProtection,
    TRIM(TechSupport) AS TechSupport,
    TRIM(StreamingTV) AS StreamingTV,
    TRIM(StreamingMovies) AS StreamingMovies,

    TRIM(Contract) AS Contract,
    TRIM(PaperlessBilling) AS PaperlessBilling,
    TRIM(PaymentMethod) AS PaymentMethod,

    CAST(MonthlyCharges AS DECIMAL(10,2)) AS MonthlyCharges,

    CASE
        WHEN NULLIF(TRIM(CAST(TotalCharges AS CHAR)), '') IS NULL
             AND CAST(tenure AS UNSIGNED) = 0
        THEN CAST(0 AS DECIMAL(10,2))
        ELSE CAST(
            NULLIF(TRIM(CAST(TotalCharges AS CHAR)), '')
            AS DECIMAL(10,2)
        )
    END AS TotalCharges,

    CAST(numAdminTickets AS UNSIGNED) AS numAdminTickets,
    CAST(numTechTickets AS UNSIGNED) AS numTechTickets,

    TRIM(Churn) AS Churn

FROM customerchurn_raw;


-- =========================================================
-- 05. VALIDATE THE CLEANED DATA
-- =========================================================

SELECT
    COUNT(*) AS total_cleaned_records,
    COUNT(DISTINCT customerID) AS unique_customers,
    SUM(customerID IS NULL OR customerID = '') AS missing_customerID,
    SUM(TotalCharges IS NULL) AS missing_totalcharges,
    SUM(MonthlyCharges IS NULL) AS missing_monthlycharges,
    SUM(Churn IS NULL OR Churn = '') AS missing_churn
FROM customerchurn_cleaned;

-- Check duplicate IDs after cleaning.
SELECT
    customerID,
    COUNT(*) AS duplicate_count
FROM customerchurn_cleaned
GROUP BY customerID
HAVING COUNT(*) > 1;

-- Check cleaned table structure.
DESCRIBE customerchurn_cleaned;


-- =========================================================
-- 06. CUSTOMER BASE INSIGHTS - DASHBOARD 1
-- =========================================================

-- 6.1 Main KPI cards:
-- Total Customers, Churn Rate, Average Monthly Charges,
-- Total Revenue (sum of TotalCharges).

SELECT
    COUNT(DISTINCT customerID) AS total_customers,

    ROUND(
        100.0 * SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0), 2
    ) AS churn_rate_percentage,

    ROUND(AVG(MonthlyCharges), 2) AS avg_monthly_charges,

    ROUND(SUM(TotalCharges), 2) AS total_revenue

FROM customerchurn_cleaned;


-- 6.2 Customers by Internet Service.
SELECT
    InternetService,
    COUNT(*) AS total_customers
FROM customerchurn_cleaned
GROUP BY InternetService
ORDER BY total_customers DESC;


-- 6.3 Customers by Contract.
SELECT
    Contract,
    COUNT(*) AS total_customers
FROM customerchurn_cleaned
GROUP BY Contract
ORDER BY total_customers DESC;


-- 6.4 Customers by Payment Method.
SELECT
    PaymentMethod,
    COUNT(*) AS total_customers
FROM customerchurn_cleaned
GROUP BY PaymentMethod
ORDER BY total_customers DESC;


-- 6.5 Monthly Charges distribution.
SELECT
    CASE
        WHEN MonthlyCharges < 38 THEN '18-38'
        WHEN MonthlyCharges < 58 THEN '38-58'
        WHEN MonthlyCharges < 78 THEN '58-78'
        WHEN MonthlyCharges < 98 THEN '78-98'
        ELSE '98-119'
    END AS monthly_charges_range,
    COUNT(*) AS total_customers
FROM customerchurn_cleaned
GROUP BY monthly_charges_range
ORDER BY MIN(MonthlyCharges);


-- 6.6 Customer distribution by tenure (tenure is in months).
SELECT
    CASE
        WHEN tenure < 12 THEN '<1'
        WHEN tenure < 24 THEN '1-2'
        WHEN tenure < 36 THEN '2-3'
        WHEN tenure < 48 THEN '3-4'
        WHEN tenure < 60 THEN '4-5'
        ELSE '5-6'
    END AS tenure_group_years,
    COUNT(*) AS total_customers
FROM customerchurn_cleaned
GROUP BY tenure_group_years
ORDER BY MIN(tenure);


-- 6.7 Customer demographics.
SELECT
    gender,
    SeniorCitizen,
    Partner,
    Dependents,
    COUNT(*) AS total_customers
FROM customerchurn_cleaned
GROUP BY gender, SeniorCitizen, Partner, Dependents
ORDER BY total_customers DESC;


-- 6.8 Service distribution across ALL customers.
-- Percentages in this query use all customers as the denominator.
SELECT
    service_name,
    ROUND(100.0 * SUM(service_status = 'No') / COUNT(*), 2) AS no_percentage,
    ROUND(100.0 * SUM(service_status = 'No internet service') / COUNT(*), 2) AS no_internet_percentage,
    ROUND(100.0 * SUM(service_status = 'Yes') / COUNT(*), 2) AS yes_percentage
FROM (
    SELECT 'Online Backup' AS service_name, OnlineBackup AS service_status
    FROM customerchurn_cleaned
    UNION ALL
    SELECT 'Online Security', OnlineSecurity FROM customerchurn_cleaned
    UNION ALL
    SELECT 'Device Protection', DeviceProtection FROM customerchurn_cleaned
    UNION ALL
    SELECT 'Tech Support', TechSupport FROM customerchurn_cleaned
    UNION ALL
    SELECT 'Streaming Movies', StreamingMovies FROM customerchurn_cleaned
    UNION ALL
    SELECT 'Streaming TV', StreamingTV FROM customerchurn_cleaned
) AS service_data
GROUP BY service_name
ORDER BY service_name;


-- =========================================================
-- 07. CHURNED CUSTOMER ANALYSIS - DASHBOARD 2
-- =========================================================

-- 7.1 Churned vs retained customers.
SELECT
    Churn,
    COUNT(*) AS customer_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS customer_percentage
FROM customerchurn_cleaned
GROUP BY Churn;


-- 7.2 Churn rate by Contract.
SELECT
    Contract,
    COUNT(*) AS total_customers,
    SUM(Churn = 'Yes') AS churned_customers,
    ROUND(100.0 * SUM(Churn = 'Yes') / COUNT(*), 2) AS churn_rate
FROM customerchurn_cleaned
GROUP BY Contract
ORDER BY churn_rate DESC;


-- 7.3 Churn rate by Payment Method.
SELECT
    PaymentMethod,
    COUNT(*) AS total_customers,
    SUM(Churn = 'Yes') AS churned_customers,
    ROUND(100.0 * SUM(Churn = 'Yes') / COUNT(*), 2) AS churn_rate
FROM customerchurn_cleaned
GROUP BY PaymentMethod
ORDER BY churn_rate DESC;


-- 7.4 Churn rate by Internet Service.
SELECT
    InternetService,
    COUNT(*) AS total_customers,
    SUM(Churn = 'Yes') AS churned_customers,
    ROUND(100.0 * SUM(Churn = 'Yes') / COUNT(*), 2) AS churn_rate
FROM customerchurn_cleaned
GROUP BY InternetService
ORDER BY churn_rate DESC;


-- 7.5 Service KPI cards for the CHURNED customer population.
-- Denominator = all churned customers (Churn = 'Yes').
-- These are the percentages intended to match the second dashboard.
SELECT
    service_name,
    SUM(service_status = 'Yes') AS churned_customers_with_service,
    COUNT(*) AS total_churned_customers,
    ROUND(100.0 * SUM(service_status = 'Yes') / COUNT(*), 0)
        AS churned_customer_percentage
FROM (
    SELECT 'Online Backup' AS service_name, Churn, OnlineBackup AS service_status
    FROM customerchurn_cleaned
    WHERE Churn = 'Yes'

    UNION ALL
    SELECT 'Online Security', Churn, OnlineSecurity
    FROM customerchurn_cleaned
    WHERE Churn = 'Yes'

    UNION ALL
    SELECT 'Device Protection', Churn, DeviceProtection
    FROM customerchurn_cleaned
    WHERE Churn = 'Yes'

    UNION ALL
    SELECT 'Tech Support', Churn, TechSupport
    FROM customerchurn_cleaned
    WHERE Churn = 'Yes'

    UNION ALL
    SELECT 'Paperless Billing', Churn, PaperlessBilling
    FROM customerchurn_cleaned
    WHERE Churn = 'Yes'

    UNION ALL
    SELECT 'Streaming Movies', Churn, StreamingMovies
    FROM customerchurn_cleaned
    WHERE Churn = 'Yes'

    UNION ALL
    SELECT 'Streaming TV', Churn, StreamingTV
    FROM customerchurn_cleaned
    WHERE Churn = 'Yes'
) AS churned_service_data
GROUP BY service_name
ORDER BY FIELD(
    service_name,
    'Online Backup',
    'Online Security',
    'Device Protection',
    'Tech Support',
    'Paperless Billing',
    'Streaming Movies',
    'Streaming TV'
);


-- 7.6 Churn rate by monthly charge range.
SELECT
    CASE
        WHEN MonthlyCharges < 38 THEN '18-38'
        WHEN MonthlyCharges < 58 THEN '38-58'
        WHEN MonthlyCharges < 78 THEN '58-78'
        WHEN MonthlyCharges < 98 THEN '78-98'
        ELSE '98-119'
    END AS monthly_charges_range,
    COUNT(*) AS total_customers,
    SUM(Churn = 'Yes') AS churned_customers,
    ROUND(100.0 * SUM(Churn = 'Yes') / COUNT(*), 2) AS churn_rate
FROM customerchurn_cleaned
GROUP BY monthly_charges_range
ORDER BY MIN(MonthlyCharges);


-- 7.7 Churn rate by tenure group.
SELECT
    CASE
        WHEN tenure < 12 THEN '<1 Year'
        WHEN tenure < 24 THEN '1-2 Years'
        WHEN tenure < 36 THEN '2-3 Years'
        WHEN tenure < 48 THEN '3-4 Years'
        WHEN tenure < 60 THEN '4-5 Years'
        ELSE '5-6 Years'
    END AS tenure_group,
    COUNT(*) AS total_customers,
    SUM(Churn = 'Yes') AS churned_customers,
    ROUND(100.0 * SUM(Churn = 'Yes') / COUNT(*), 2) AS churn_rate
FROM customerchurn_cleaned
GROUP BY tenure_group
ORDER BY MIN(tenure);


-- 7.8 Churn rate by customer demographics.
SELECT
    gender,
    SeniorCitizen,
    Partner,
    Dependents,
    COUNT(*) AS total_customers,
    SUM(Churn = 'Yes') AS churned_customers,
    ROUND(100.0 * SUM(Churn = 'Yes') / COUNT(*), 2) AS churn_rate
FROM customerchurn_cleaned
GROUP BY gender, SeniorCitizen, Partner, Dependents
ORDER BY churn_rate DESC;


-- =========================================================
-- 08. ADDITIONAL BUSINESS ANALYSIS
-- =========================================================

-- 8.1 Technical support tickets and churn.
SELECT
    CASE
        WHEN numTechTickets = 0 THEN 'No Tickets'
        WHEN numTechTickets BETWEEN 1 AND 2 THEN '1-2 Tickets'
        WHEN numTechTickets BETWEEN 3 AND 5 THEN '3-5 Tickets'
        ELSE 'More than 5 Tickets'
    END AS technical_ticket_group,
    COUNT(*) AS total_customers,
    SUM(Churn = 'Yes') AS churned_customers,
    ROUND(100.0 * SUM(Churn = 'Yes') / COUNT(*), 2) AS churn_rate
FROM customerchurn_cleaned
GROUP BY technical_ticket_group
ORDER BY MIN(numTechTickets);


-- 8.2 Admin support tickets and churn.
SELECT
    CASE
        WHEN numAdminTickets = 0 THEN 'No Tickets'
        WHEN numAdminTickets BETWEEN 1 AND 2 THEN '1-2 Tickets'
        WHEN numAdminTickets BETWEEN 3 AND 5 THEN '3-5 Tickets'
        ELSE 'More than 5 Tickets'
    END AS admin_ticket_group,
    COUNT(*) AS total_customers,
    SUM(Churn = 'Yes') AS churned_customers,
    ROUND(100.0 * SUM(Churn = 'Yes') / COUNT(*), 2) AS churn_rate
FROM customerchurn_cleaned
GROUP BY admin_ticket_group
ORDER BY MIN(numAdminTickets);


-- 8.3 Revenue and monthly charges by churn status.
SELECT
    Churn,
    COUNT(*) AS total_customers,
    ROUND(SUM(TotalCharges), 2) AS total_revenue,
    ROUND(AVG(MonthlyCharges), 2) AS avg_monthly_charges,
    ROUND(AVG(TotalCharges), 2) AS avg_total_charges
FROM customerchurn_cleaned
GROUP BY Churn;

-- Contract distribution among churned customers
SELECT
    Contract,
    COUNT(*) AS Churned_Customers,
    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER(), 2
    ) AS Percentage
FROM customerchurn_cleaned
WHERE Churn = 'Yes'
GROUP BY Contract;

--Payment Method distribution among churned customers
SELECT
    PaymentMethod,
    COUNT(*) AS Churned_Customers
FROM customerchurn_cleaned
WHERE Churn = 'Yes'
GROUP BY PaymentMethod
ORDER BY Churned_Customers DESC;

--Internet Service distribution among churned customers
SELECT
    InternetService,
    COUNT(*) AS Churned_Customers,
    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER(), 2
    ) AS Percentage
FROM customerchurn_cleaned
WHERE Churn = 'Yes'
GROUP BY InternetService;

--– Monthly Charges distribution among churned customers
SELECT
    CASE
        WHEN MonthlyCharges < 38 THEN '18-38'
        WHEN MonthlyCharges < 58 THEN '38-58'
        WHEN MonthlyCharges < 78 THEN '58-78'
        WHEN MonthlyCharges < 98 THEN '78-98'
        ELSE '98-119'
    END AS Monthly_Charges_Range,

    COUNT(*) AS Churned_Customers

FROM customerchurn_cleaned
WHERE Churn = 'Yes'

GROUP BY Monthly_Charges_Range
ORDER BY MIN(MonthlyCharges);

-- Tenure distribution among churned customers
SELECT
    CASE
        WHEN tenure < 12 THEN '<1'
        WHEN tenure < 24 THEN '1-2'
        WHEN tenure < 36 THEN '2-3'
        WHEN tenure < 48 THEN '3-4'
        WHEN tenure < 60 THEN '4-5'
        ELSE '5-6'
    END AS Tenure_Group,

    COUNT(*) AS Churned_Customers

FROM customerchurn_cleaned
WHERE Churn = 'Yes'

GROUP BY Tenure_Group
ORDER BY MIN(tenure);




-- =========================================================
-- 09. FINAL PROJECT VALIDATION
-- =========================================================

SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT customerID) AS unique_customers,
    SUM(Churn = 'Yes') AS churned_customers,
    SUM(Churn = 'No') AS retained_customers,
    ROUND(100.0 * SUM(Churn = 'Yes') / COUNT(*), 2) AS churn_rate,
    ROUND(AVG(MonthlyCharges), 2) AS avg_monthly_charges,
    ROUND(SUM(TotalCharges), 2) AS total_revenue
FROM customerchurn_cleaned;

/*
REFERENCE CHECKS FROM THE PROVIDED RAW DATA:
- Total records: 7,043
- Unique customer IDs: 7,043
- Churned customers: 1,869
- Retained customers: 5,174
- Churn rate: 26.54%
- Average monthly charges: $64.76
- Sum of TotalCharges: $16,056,168.70
- Blank TotalCharges records: 11 (zero-tenure records)

CHURNED-CUSTOMER SERVICE KPI PERCENTAGES (rounded to whole numbers):
- Online Backup: 28%
- Online Security: 16%
- Device Protection: 29%
- Tech Support: 17%
- Paperless Billing: 75%
- Streaming Movies: 44%
- Streaming TV: 44%

NOTE:
The service KPI percentages above use the churned customer population
as the denominator. The service distribution query in section 6.8
uses all customers as the denominator. These are different metrics.

TotalCharges is the sum of historical customer charges in the dataset.
It should not be described as monthly revenue or forecast revenue.
*/
