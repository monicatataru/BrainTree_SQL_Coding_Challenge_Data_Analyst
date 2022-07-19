/*
1. Data Integrity Checking & Cleanup
Alphabetically list all of the country codes in the continent_map table that appear more than once. 
Display any values where country_code is null as country_code = "FOO" and make this row appear first in the list, 
even though it should alphabetically sort to the middle. Provide the results of this query as your answer.
*/

SELECT COALESCE(country_code, 'FOO')
from continent_map
GROUP BY country_code
HAVING COUNT(*)>1
ORDER BY country_code

/*  
For all countries that have multiple rows in the continent_map table, delete all multiple records leaving only the 1 record per country. 
The record that you keep should be the first one when sorted by the continent_code alphabetically ascending. 
Provide the query/ies and explanation of step(s) that you follow to delete these records.
*/

WITH cte AS
(SELECT country_code, continent_code,
    ROW_NUMBER() OVER ( PARTITION BY country_Code
                        ORDER BY continent_code) as row_n
FROM continent_map)
DELETE
FROM cte
WHERE row_n > 1

/*
2. List the countries ranked 10-12 in each continent by the percent of year-over-year growth descending from 2011 to 2012.
The percent of growth should be calculated as: ((2012 gdp - 2011 gdp) / 2011 gdp)
The list should include the columns:
    rank
    continent_name
    country_code
    country_name
    growth_percent
*/
WITH cte AS(
SELECT country_dtl.continent_name, country_dtl.country_code, country_dtl.country_name,
    RANK() OVER (PARTITION BY country_dtl.continent_name
                    ORDER BY gdp_2012vs2011 DESC) AS ranking,
    COALESCE(gdp_2012vs2011,0) AS gdp_variation
FROM (
SELECT DISTINCT gdp_2012.country_code , 
            round((gdp_2012.gdp_per_capita-gdp_2011.gdp_per_capita)/gdp_2011.gdp_per_capita*100.00,2) AS gdp_2012vs2011
FROM
   --2012
    (select * from per_capita
    WHERE year=2012) gdp_2012
LEFT JOIN 
    --2011
    (select * from per_capita
    WHERE year=2011) gdp_2011
ON gdp_2012.country_code = gdp_2011.country_code
) gdp_table
JOIN
(SELECT continents.continent_name, countries.country_code, countries.country_name FROM countries 
JOIN continent_map
ON countries.country_code = continent_map.country_code
JOIN continents
ON continent_map.continent_code = continents.continent_code) country_dtl
ON gdp_table.country_code = country_dtl.country_code
)
SELECT *
FROM cte
WHERE ranking BETWEEN 10 AND 12

/*
3. For the year 2012, create a 3 column, 1 row report showing the percent share of gdp_per_capita for the following regions:

(i) Asia, (ii) Europe, (iii) the Rest of the World. Your result should look something like

Asia	Europe	Rest of World
25.0%	25.0%	50.0%
*/


SELECT CONCAT(ROUND(SUM(CASE WHEN continents.continent_name='Asia' THEN gdp_per_capita ELSE NULL END)/SUM(gdp_per_capita)*100,1),'%') AS Asia,
       CONCAT(ROUND(SUM(CASE WHEN continents.continent_name='Europe' THEN gdp_per_capita ELSE NULL END)/SUM(gdp_per_capita)*100,1),'%') AS Europe,
       CONCAT(ROUND(SUM(CASE WHEN continents.continent_name NOT IN ('Europe','Asia') THEN gdp_per_capita ELSE NULL END)/SUM(gdp_per_capita)*100,1),'%') AS Rest_of_World
FROM per_capita
JOIN continent_map ON per_capita.country_code = continent_map.country_code
JOIN continents ON continent_map.continent_code = continents.continent_code
WHERE year = 2012

/*
4a. What is the count of countries and sum of their related gdp_per_capita values for the year 2007 where the string 'an' (case insensitive) appears anywhere in the country name?
*/

SELECT COUNT(per_capita.country_code) AS Countries_No,
        ROUND(SUM(gdp_per_capita),2) AS GDP
FROM per_capita
JOIN countries
on per_capita.country_code = countries.country_code
WHERE year = 2007 AND country_name LIKE '%an%'


/* 4b. Repeat question 4a, but this time make the query case sensitive. */
SELECT COUNT(per_capita.country_code) AS Countries_No,
       ROUND(SUM(gdp_per_capita),2) AS GDP
FROM per_capita
JOIN countries
on per_capita.country_code = countries.country_code
WHERE year = 2007 AND country_name COLLATE Latin1_General_CS_AS LIKE '%an%'

/*
5. Find the sum of gpd_per_capita by year and the count of countries for each year that have non-null gdp_per_capita where 
(i) the year is before 2012 and 
(ii) the country has a null gdp_per_capita in 2012. Your result should have the columns:

year
country_count
total
*/

SELECT year, 
        SUM(CASE WHEN gdp_per_capita IS NULL THEN 1 ELSE 0 END) AS country_count,
        ROUND(SUM(gdp_per_capita),2) AS total
FROM per_capita
WHERE country_code IN (SELECT DISTINCT country_code
    FROM per_capita
    WHERE gdp_per_capita IS NULL AND year = 2012)
AND year < 2012
GROUP BY year
ORDER BY year

/*
6. All in a single query, execute all of the steps below and provide the results as your final answer:
a. create a single list of all per_capita records for year 2009 that includes columns:
    continent_name
    country_code
    country_name
    gdp_per_capita
b. order this list by:
    continent_name ascending
    characters 2 through 4 (inclusive) of the country_name descending

c. create a running total of gdp_per_capita by continent_name

d. return only the first record from the ordered list for which each continent's running total of gdp_per_capita meets or exceeds $70,000.00 with the following columns:
    continent_name
    country_code
    country_name
    gdp_per_capita
    running_total
*/

SELECT a.continent_name, country_code, country_name, 
        ROUND(gdp_per_capita,2) AS gdp_per_capita,
        ROUND(running_total,2) AS running_total 
FROM
(
SELECT min(b.row_no) AS row_no, continent_name FROM (
    SELECT continent_name,
    per_capita.country_code,
    country_name,
    gdp_per_capita,
    ROW_NUMBER() OVER (PARTITION BY continent_name
                         ORDER BY continent_name, SUBSTRING(country_name,2, 3) DESC) AS row_no,
    SUM(gdp_per_capita) OVER (PARTITION BY continent_name
                              ORDER BY continent_name, SUBSTRING(country_name,2, 3) DESC) as running_total
FROM per_capita
JOIN countries ON per_capita.country_code = countries.country_code
JOIN continent_map ON per_capita.country_code = continent_map.country_code
JOIN continents ON continent_map.continent_code = continents.continent_code
WHERE year = 2009) b
WHERE running_total >= 70000
GROUP BY continent_name) a

LEFT JOIN 
(
    SELECT continent_name,
    per_capita.country_code,
    country_name,
    gdp_per_capita,
    ROW_NUMBER() OVER (PARTITION BY continent_name
                         ORDER BY continent_name, SUBSTRING(country_name,2, 3) DESC) AS row_no,
    SUM(gdp_per_capita) OVER (PARTITION BY continent_name
                              ORDER BY continent_name, SUBSTRING(country_name,2, 3) DESC) as running_total
FROM per_capita
JOIN countries ON per_capita.country_code = countries.country_code
JOIN continent_map ON per_capita.country_code = continent_map.country_code
JOIN continents ON continent_map.continent_code = continents.continent_code
WHERE year = 2009) c
ON a.row_no = c.row_no AND a.continent_name = c.continent_name

/*
7. Find the country with the highest average gdp_per_capita for each continent for all years. Now compare your list to the following data set. 
Please describe any and all mistakes that you can find with the data set below.
Include any code that you use to help detect these mistakes.
*/


WITH cte AS (
SELECT RANK() OVER (PARTITION BY continent_name
                     ORDER BY avg_gdp_per_capita DESC) AS rnk,
        continent_name,
        country_code,
        country_name, 
        CONCAT('$',CONVERT(VARCHAR,CONVERT(MONEY,avg_gdp_per_capita),1)) AS avg_gdp_per_capita
        
FROM (
    SELECT continent_name, countries.country_code, country_name,
        AVG(CASE WHEN country_name= country_name THEN gdp_per_capita END) AS avg_gdp_per_capita
    FROM per_capita
    JOIN countries ON per_capita.country_code = countries.country_code
    JOIN continent_map ON per_capita.country_code = continent_map.country_code
    JOIN continents ON continent_map.continent_code = continents.continent_code
    GROUP BY continent_name, countries.country_code, country_name) a
    )
SELECT * FROM cte 
WHERE rnk = 1



