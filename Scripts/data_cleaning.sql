-- DATA CLEANING

-- 1. Remove Duplicates
-- 2. Standardize the Data and Fix Errors
-- 3. Null Values or Blank Values
-- 4. Remove Any Columns

SELECT * FROM layoffs;

-- 1. Remove Duplicates
-- Make a copy of the table you're working with
CREATE TABLE layoffs_staging LIKE layoffs;

-- Add a column to label unique rows: (1) - unique, (2+) - duplicate
ALTER TABLE layoffs_staging ADD COLUMN row_num INT;

-- Populate the new table
-- `date`(back ticks) its written like this because there is a command DATE (to avoid an error)

INSERT layoffs_staging
SELECT * ,
ROW_NUMBER() OVER(PARTITION BY company, location, industry, total_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
FROM layoffs;

SELECT *
FROM layoffs_staging;

-- Delete duplicates
DELETE FROM layoffs_staging 
WHERE row_num > 1;


-- 2.Standardize DATA
-- Find Inconsistencies - unique companies in this case

SELECT COUNT(*), COUNT(DISTINCT company) 
FROM layoffs_staging;

-- DIAGNOSTIC TEST: See exactly how many rows have hidden space defects

SELECT COUNT(*) AS rows_with_hidden_spaces
FROM layoffs_staging
WHERE LENGTH(company) != LENGTH(TRIM(company))
   OR LENGTH(location) != LENGTH(TRIM(location))
   OR LENGTH(industry) != LENGTH(TRIM(industry))
   OR LENGTH(country) != LENGTH(TRIM(country))
   OR LENGTH(stage) != LENGTH(TRIM(stage));

-- TARGETED FIX: Sniper-update ONLY the rows that actually need it, all at once
UPDATE layoffs_staging
SET 
    company  = TRIM(company),
    location = TRIM(location),
    industry = TRIM(industry),
    country  = TRIM(country),
    stage    = TRIM(stage)
WHERE LENGTH(company) != LENGTH(TRIM(company))
   OR LENGTH(location) != LENGTH(TRIM(location))
   OR LENGTH(industry) != LENGTH(TRIM(industry))
   OR LENGTH(country) != LENGTH(TRIM(country))
   OR LENGTH(stage) != LENGTH(TRIM(stage));
   
-- Spelling check
-- Look at every DISTICT TEXT column

SELECT DISTINCT industry
FROM layoffs_staging
ORDER BY 1;

UPDATE layoffs_staging
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

UPDATE layoffs_staging
SET industry = NULL
WHERE industry = '';

-- By clicking on layoffs_staging table you can see date is in text format

UPDATE layoffs_staging
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

ALTER TABLE layoffs_staging
MODIFY COLUMN `date` DATE;

-- Check The INT based columns
SELECT * FROM layoffs_staging WHERE percentage_laid_off > 1;

UPDATE layoffs_staging
SET total_laid_off = NULL
WHERE total_laid_off = 0;

-- Ensure total_laid_off is an INT (Whole numbers only)
ALTER TABLE layoffs_staging
MODIFY COLUMN total_laid_off INT;

-- Ensure percentage_laid_off is a FLOAT or DECIMAL (For precision)
ALTER TABLE layoffs_staging
MODIFY COLUMN percentage_laid_off DECIMAL(6, 2);

-- Clean Punctuation
SELECT DISTINCT country
FROM layoffs_staging;

UPDATE layoffs_staging
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

-- Visual Verification Scan - go column by clumn and inspect for errors

SELECT DISTINCT company FROM layoffs_staging ORDER BY 1;
SELECT DISTINCT location FROM layoffs_staging ORDER BY 1;
SELECT DISTINCT industry FROM layoffs_staging ORDER BY 1;
SELECT DISTINCT country FROM layoffs_staging ORDER BY 1;
SELECT DISTINCT stage FROM layoffs_staging ORDER BY 1;

-- 3. Checking for NULLs and ' ' column by column

-- Identify
SELECT *
FROM layoffs_staging
WHERE industry IS NULL 
   OR industry = '';
   
-- Self-Join - First, run a SELECT to verify what you are about to update
SELECT t1.company, t1.industry, t2.industry
FROM layoffs_staging t1
JOIN layoffs_staging t2
    ON t1.company = t2.company
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;

-- Now, perform the actual UPDATE
UPDATE layoffs_staging t1
JOIN layoffs_staging t2
    ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;

-- Check how many rows you are about to lose
SELECT *
FROM layoffs_staging
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;


-- 4. THE CLEANUP (DELETING USELESS ROWS & DROPPING TEMP COLUMNS)

-- Temporarily unlock the database safety switch
SET SQL_SAFE_UPDATES = 0;

-- Delete rows where both critical metric columns are useless
DELETE
FROM layoffs_staging
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;

-- Lock the safety switch back up immediately (Best Practice!)
SET SQL_SAFE_UPDATES = 1;

-- Remove the temporary column - row_num
ALTER TABLE layoffs_staging
DROP COLUMN row_num;

-- CLEAN DATA
SELECT * FROM layoffs_staging;

-- Check the usuable DATA
SELECT company, stage, country, total_laid_off, percentage_laid_off, `date`
FROM layoffs_staging
WHERE company IN (
    SELECT company 
    FROM layoffs_staging 
    WHERE total_laid_off IS NOT NULL AND percentage_laid_off IS NOT NULL
)
ORDER BY company, `date`;

-- Works in MySQL



