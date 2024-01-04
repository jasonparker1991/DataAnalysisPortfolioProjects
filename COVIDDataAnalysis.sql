/*

Title: COVID-19 Data Exploration 
Author: Jason Parker
Date: 2023-12-30

*/

SELECT 
	*
FROM 
	CovidDeaths
ORDER BY 
	location, date;

SELECT 
	*
FROM 
	CovidVaccinations
ORDER BY 
	location, date;

/*
After taking an initial look at the data in both tables, I see that there are certain
locations, such as Africa, that have a blank value in the continent column. I now want to
find all such locations, so that I can remove them from consideration when analyzing the data
(otherwise certain locations may be counted more than once).
*/

SELECT 
	DISTINCT(location)
FROM 
	CovidDeaths
WHERE 
	continent = '';

/*
 All of the locations with a blank continent are continents and World. So in the queries below,
 I will filter out the locations with a blank continent.
 */

-- Now I will select the data from the CovidDeaths table that I will be primarily using.

SELECT 
	location, 
	date, 
	total_cases, 
	new_cases, 
	total_deaths, 
	population
FROM 
	CovidDeaths
WHERE 
	continent != ''
ORDER BY 
	location, date;

-- The death_rate column in the next query calculates one's likelihood of dying from COVID-19 once it is contracted.

SELECT 
	location, 
	date, 
	population, 
	total_cases, 
	total_deaths, 
	(total_deaths/total_cases)*100 AS death_rate
FROM 
	CovidDeaths
WHERE 
	continent != ''
ORDER BY 
	location, date;

-- The case_rate column in the next query calculates the percentage of the population that has contracted COVID-19.

SELECT 
	location, 
	date, 
	population, 
	total_cases, 
	(total_cases/population)*100 AS case_rate
FROM 
	CovidDeaths
WHERE 
	continent != ''
ORDER BY 
	location, date;

-- The next query illustrates the locations that have the highest population infection rate.

SELECT 
	location, 
	population, 
	MAX(total_cases) AS HighestInfectionCount, 
	MAX((total_cases/population)*100) AS HighestInfectionRate
FROM 
	CovidDeaths
WHERE 
	continent != ''
GROUP BY 
	location, population
ORDER BY 
	HighestInfectionRate DESC;

-- The next query illustrates the locations that have the highest COVID-19 death counts.

SELECT 
	location, 
	MAX(total_deaths) AS HighestDeathCount
FROM 
	CovidDeaths
WHERE 
	continent != ''
GROUP BY 
	location
ORDER BY 
	HighestDeathCount DESC;

-- The next query shows the highest death count from COVID-19 for each continent (and the entire world).

SELECT 
	location, 
	MAX(total_deaths) AS HighestDeathCount
FROM 
	CovidDeaths
WHERE 
	continent = '' -- This ensures that only the continent locations are selected.
GROUP BY 
	location
ORDER BY 
	HighestDeathCount DESC;

-- The next query shows, for each date, the number of new global COVID-19 cases, the number of new global COVID-19 deaths, and the global death rate from COVID-19.

SELECT 
	date, 
	SUM(new_cases) as TotalNewCases, 
	SUM(new_deaths) as TotalNewDeaths, 
	(SUM(new_deaths)/SUM(new_cases))*100 AS NewGlobalDeathRate
FROM 
	CovidDeaths
WHERE 
	continent != ''
GROUP BY 
	date
ORDER BY 
	date;

/*
In the next query, I join the CovidDeaths and CovidVaccinations tables on the location and date fields. I then
use window functions to create the calculated fields RollingPeopleVaccinated and RollingPercentVaccinated, which
respectively calculate, for each location, the rolling number of people vaccinated, and the rolling proportion of people
vaccinated. 
 */

SELECT 
	cd.continent, 
	cd.location, 
	cd.date, 
	cd.population, 
	cv.new_vaccinations, 
	SUM(CAST(cv.new_vaccinations AS UNSIGNED)) OVER(PARTITION BY cd.location ORDER BY cd.location, cd.date) AS RollingPeopleVaccinated,
	((SUM(CAST(cv.new_vaccinations AS UNSIGNED)) OVER(PARTITION BY cd.location ORDER BY cd.location, cd.date))/Population)*100 AS RollingPercentVaccinated
FROM 
	CovidDeaths cd 
JOIN 
	CovidVaccinations cv 
ON 
	cd.location = cv.location AND cd.date = cv.date
WHERE 
	cd.continent != ''
ORDER BY 
	cd.location, cd.date;

-- Calculating the RollingPercentVaccinated field in the previous query was somewhat messy, so we can simplify its calculation by using the CTE PopvsVac below.

WITH PopvsVac (Continent, Location, Date, Population, New_Vaccinations, RollingPeopleVaccinated)
AS
(
SELECT 
	cd.continent, 
	cd.location, 
	cd.date, 
	cd.population, 
	cv.new_vaccinations, 
	SUM(CAST(cv.new_vaccinations AS UNSIGNED)) OVER(PARTITION BY cd.location ORDER BY cd.location, cd.date) AS RollingPeopleVaccinated
FROM 
	CovidDeaths cd 
JOIN 
	CovidVaccinations cv 
ON 
	cd.location = cv.location AND cd.date = cv.date
WHERE 
	cd.continent != ''
)

SELECT *, (RollingPeopleVaccinated/Population)*100 AS RollingPercentVaccinated
FROM PopvsVac;

-- Lastly, I create the view RollingPopulationVaccinated to store data for a later visualization.

DROP VIEW IF EXISTS RollingPopulationVaccinated

CREATE VIEW RollingPopulationVaccinated
AS
SELECT 
	cd.continent, 
	cd.location, 
	cd.date, 
	cd.population, 
	cv.new_vaccinations, 
	SUM(CAST(cv.new_vaccinations AS UNSIGNED)) OVER(PARTITION BY cd.location ORDER BY cd.location, cd.date) AS RollingPeopleVaccinated,
	((SUM(CAST(cv.new_vaccinations AS UNSIGNED)) OVER(PARTITION BY cd.location ORDER BY cd.location, cd.date))/Population)*100 AS RollingPercentVaccinated
FROM 
	CovidDeaths cd 
JOIN 
	CovidVaccinations cv 
ON 
	cd.location = cv.location AND cd.date = cv.date
WHERE 
	cd.continent != '';







