CREATE TABLE buffalo_crime(
	incident_id VARCHAR(20) PRIMARY KEY,
    incident_datetime TIMESTAMP,
    incident_type VARCHAR(100),
    hour_of_day INTEGER,
    day_of_week VARCHAR(10),
    address TEXT,
    city VARCHAR(50),
    state VARCHAR(5),
    zip_code VARCHAR(10),
    neighborhood VARCHAR(100),
    council_district VARCHAR(50),
    police_district VARCHAR(50)

)
SELECT * 
FROM buffalo_crime
LIMIT 10

-- CLEANING AND VALIDATIONS
-- Checking for duplicates (Should return 0)


SELECT incident_id, COUNT(*) 
FROM buffalo_crime
GROUP BY incident_id
HAVING COUNT(*) > 1



--  Checking for NULLs in critical columns

SELECT *
FROM buffalo_crime
WHERE incident_id IS NULL OR incident_datetime IS NULL	
OR incident_type IS NULL;


-- Creating 2 new columns one for year and one for month

ALTER TABLE buffalo_crime ADD COLUMN incident_year INTEGER;
ALTER TABLE buffalo_crime ADD COLUMN incident_month INTEGER;

UPDATE buffalo_crime
SET incident_year = EXTRACT(YEAR FROM incident_datetime),
 incident_month = EXTRACT(MONTH FROM incident_datetime);

--- Creating a new column that breaks down the time of the day into sections

ALTER TABLE buffalo_crime ADD COLUMN time_of_the_day VARCHAR(20);
UPDATE buffalo_crime
SET time_of_the_day = CASE
	 WHEN hour_of_day BETWEEN 5 AND 11 THEN 'Morning'
	 WHEN hour_of_day BETWEEN 12 AND 16 THEN 'Afternoon'
	 WHEN hour_of_day BETWEEN 17 AND 20 THEN 'Evening'
	 ELSE 'Night'
END;


--Standardizing text case and fixing common inconsistencie(UPPER case to lower case)

UPDATE buffalo_crime
SET address = INITCAP(LOWER(address));

UPDATE buffalo_crime
SET council_district = INITCAP(LOWER(council_district));

UPDATE buffalo_crime
SET police_district = INITCAP(LOWER(police_district));

UPDATE buffalo_crime
SET neighborhood = INITCAP(LOWER(neighborhood));


-- Dealing with nuls(where ever theres is null replace it with unknown)

UPDATE buffalo_crime
SET zip_code = 'Unknown'
WHERE zip_code IS NULL OR TRIM(zip_code ) = '';

UPDATE buffalo_crime
SET police_district = 'Unknown'
WHERE police_district IS NULL OR TRIM(police_district) = '';


UPDATE buffalo_crime
SET council_district = 'Unknown'
WHERE council_district IS NULL OR TRIM(council_district) = '';


UPDATE buffalo_crime
SET neighborhood = 'Unknown'
WHERE neighborhood IS NULL OR TRIM(neighborhood) = '';






----DATA EXPLORATION
-- the firts part of this section I will focus on discovering what the most common crime is,
CREATE VIEW common_crimes AS
	SELECT incident_type, COUNT(*) as most_common_crimes
	FROM buffalo_crime
	GROUP BY incident_type
	order by most_common_crimes desc

-- how they compare in relation to the prevouis years
-- basically trying to find out if the specific crime type increased or decreased from the prevous years
CREATE VIEW crime_trends_yoy AS
	SELECT 
		incident_type,
		incident_year,
		count(*) as incident_count,
		lag(count(*)) over(partition by incident_type order by incident_year) as the_year_before_count,
		round(
		(count(*)- lag(count(*)) over(partition by incident_type order by incident_year))/ lag(count(*)) 
		over(partition by incident_type order by incident_year)::NUMERIC *100, 2) AS year_over_year_pct_change
		--
	FROM buffalo_crime
	WHERE incident_year BETWEEN 2015 AND 2025 -- focused on the change in the last decade
	GROUP BY incident_year, incident_type
	ORDER BY incident_type, incident_year



--- I Noiticed Theft is the most common crime i want to know if its the most common crime in every police district

CREATE VIEW top_crime_by_district AS
	WITH most_common_crime_rank AS (
	SELECT
	incident_type, 
	police_district,
	COUNT(*) as incident_count,
	ROW_NUMBER() OVER ( PARTITION BY police_district ORDER BY COUNT(*) DESC) as Rank_
	FROM buffalo_crime
	WHERE police_district IS NOT NULL AND police_district != 'Unknown'
	GROUP BY police_district, incident_type
	) 
	
	SELECT 
	incident_type as most_common_crime, 
	police_district,
	incident_count
	FROM most_common_crime_rank
	WHERE Rank_ = 1
	ORDER BY incident_count DESC;


"Now that i know what crimes are the most common and the change across time in those specific crimes
now i want to find out which area these crimes are happening"


-- which neighborhood has the most crimes and i will only choose the top 10
CREATE VIEW top_neighborhoods AS
	SELECT 
	neighborhood,
	COUNT(*) as incident_count
	FROM buffalo_crime
	GROUP BY neighborhood
	ORDER BY incident_count DESC
	LIMIT 10


-- which police district has made the most arrest
CREATE VIEW district_arrest_count AS
	SELECT 
	police_district,
	COUNT(*) as arrest_count
	FROM buffalo_crime
	WHERE police_district IS NOT NULL AND police_district != 'Unknown'
	GROUP BY police_district
	ORDER BY arrest_count DESC




"Now finally i want to know when these crimes are happening"

-- What time of the day are the most crimes happening
CREATE VIEW crimes_by_time AS
	SELECT 
	    time_of_the_day,
	    COUNT(*) as incident_count
	FROM buffalo_crime
	GROUP BY time_of_the_day
	ORDER BY incident_count DESC

" Now that we know night time is when most crimes are commited i want to find out which type of crime is
most coomon at night"
CREATE VIEW top_crimes_at_night AS
	SELECT 
	    incident_type,
		time_of_the_day,
	    COUNT(*) as incident_count
	FROM buffalo_crime
	WHERE time_of_the_day = 'Night'
	GROUP BY incident_type, time_of_the_day
	ORDER BY incident_count DESC





--- Finally just show key percentages

--- percentages by time of the day
SELECT 
	time_of_the_day,
	COUNT(*),
	ROUND(
	COUNT(*)*100/(SELECT COUNT(*) FROM buffalo_crime),2) AS pct_by_time_of_day
FROM buffalo_crime
GROUP BY time_of_the_day
ORDER BY pct_by_time_of_day desc


--- Percentages by top neighborhoods

SELECT 
    neighborhood,
    COUNT(*) as incident_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM buffalo_crime), 2) as percentage_of_total
FROM buffalo_crime 
WHERE neighborhood != 'Unknown'
GROUP BY neighborhood
ORDER BY incident_count DESC
Limit 5


--- Finding out which year had the most crimes in the last 10 years and will make percentage based on that year

SELECT 
	incident_year, 
	COUNT(*) AS num_of_crimes
FROM buffalo_crime
WHERE incident_year BETWEEN 2015 AND 2025
GROUP BY incident_year
ORDER BY num_of_crimes DESC


-- Calculate overall % change from peak to latest year
SELECT 
    ROUND(
        ((SELECT COUNT(*) FROM buffalo_crime WHERE incident_year = 2025) - 
         (SELECT COUNT(*) FROM buffalo_crime WHERE incident_year = 2015)) 
        / (SELECT COUNT(*) FROM buffalo_crime WHERE incident_year = 2015)::NUMERIC * 100, 
    2) AS percent_change_from_peak;






SELECT *
FROM buffalo_crime
limit 10