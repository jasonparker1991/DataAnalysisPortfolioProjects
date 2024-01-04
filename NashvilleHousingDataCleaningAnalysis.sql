/*

Title: Nashville Housing Data Cleaning and Analysis 
Author: Jason Parker
Date: 2024-1-2

*/

SELECT 
	*
FROM 
	Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning;
	
-- Many of the rows have a blank value in the PropertyAddress field, so I will first populate those rows with the correct values in the PropertyAddress field. 

SELECT 
	*
FROM 
	Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning
WHERE 	
	PropertyAddress = '';

UPDATE Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning a
JOIN
	Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning b
ON
	a.ParcelID = b.ParcelID 
	AND 
	a.UniqueID <> b.UniqueID
SET 
	a.PropertyAddress = b.PropertyAddress 
WHERE 	
	a.PropertyAddress = '';

-- I will now separate the PropertyAddress field into street address and city fields.

SELECT 	
	PropertyAddress,
	SUBSTRING(PropertyAddress, 1, LOCATE(',', PropertyAddress)-1) AS PropertyStreetAddress,
	SUBSTRING(PropertyAddress, LOCATE(',', PropertyAddress)+1, LENGTH(PropertyAddress)) AS PropertyCity
FROM
	Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning; 

ALTER TABLE Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning 
ADD PropertyStreetAddress NVARCHAR(255);

UPDATE Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning 
SET PropertyStreetAddress = SUBSTRING(PropertyAddress, 1, LOCATE(',', PropertyAddress)-1);

ALTER TABLE Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning 
ADD PropertyCity NVARCHAR(255);

UPDATE Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning 
SET PropertyCity = SUBSTRING(PropertyAddress, LOCATE(',', PropertyAddress)+1, LENGTH(PropertyAddress));

-- I will also separate the OwnerAddress field into street address, city, and state fields.

SELECT 	
	OwnerAddress,
	SUBSTRING_INDEX(OwnerAddress,',', 1) AS OwnerStreetAddress,
	SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress,',', -2),',', 1) AS OwnerCity,
	SUBSTRING_INDEX(OwnerAddress,',', -1) AS OwnerState
FROM
	Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning; 

ALTER TABLE Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning 
ADD COLUMN (
OwnerStreetAddress NVARCHAR(255),
OwnerCity NVARCHAR(255),
OwnerState NVARCHAR(255)
);

UPDATE Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning 
SET 
	OwnerStreetAddress = SUBSTRING_INDEX(OwnerAddress,',', 1),
	OwnerCity = SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress,',', -2),',', 1),
	OwnerState = SUBSTRING_INDEX(OwnerAddress,',', -1); 

-- In the SoldAsVacant field, I will now change "Y" and "N" to "Yes" and "No" respectively.

SELECT 	
	SoldAsVacant,
	COUNT(SoldAsVacant)
FROM
	Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning
GROUP BY
	SoldAsVacant;

UPDATE Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning 
SET SoldAsVacant = CASE 
						WHEN SoldAsVacant = 'Y' THEN 'Yes'
						WHEN SoldAsVacant = 'N' THEN 'No'
						ELSE SoldAsVacant
					END;
				
-- I will now remove duplicate rows.
				
/*				
The CTE below partitions the table into groups of rows with the same ParcelID, PropertyAddress, SalePrice, SaleDate, and LegalReference, 
and then numbers the rows in each partition, ordered by UniqueID. Any row with a row_num of 2 or higher should be considered a duplicate row, 
which I will delete.
*/
				
WITH RowNumCTE
AS
(
SELECT 
	*,
	ROW_NUMBER() OVER (
	PARTITION BY	
		ParcelID,
		PropertyAddress,
		SalePrice,
		SaleDate,
		LegalReference
	ORDER BY UniqueID) AS row_num
FROM
	Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning
)

DELETE FROM
	Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning
USING
	Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning
JOIN
	RowNumCTE AS rn
ON
	Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning.UniqueID = rn.UniqueID
WHERE 	
	row_num > 1;

-- I will now delete some unused columns.

ALTER TABLE
	Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning 
DROP COLUMN OwnerAddress,
DROP COLUMN TaxDistrict,
DROP COLUMN PropertyAddress;

-- I will now clean up the LandUse column, which has several misspellings.

SELECT 
	LandUse,
	COUNT(LandUse)
FROM
	Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning
GROUP BY
	LandUse;

UPDATE Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning 
SET LandUse = CASE 
				WHEN LandUse = 'VACANT RES LAND' THEN 'VACANT RESIDENTIAL LAND'
				WHEN LandUse LIKE 'GREENBELT/RES%' THEN 'GREENBELT'
				WHEN LandUse = 'RESTURANT/CAFETERIA' THEN 'RESTAURANT/CAFETERIA'
				WHEN LandUse = 'VACANT RESIENTIAL LAND' THEN 'VACANT RESIDENTIAL LAND'
				ELSE LandUse
			  END;
			 
-- Now I will finish with some initial exploratory data analysis.
		
/*			 
This query shows the average sale price for each specific type of home (categorized by land use) and each city, 
as well as the average price of all homes in the data. 
*/
			 
SELECT 	
	LandUse,
	PropertyCity,
	COUNT(*) AS Count,
	ROUND(AVG(SalePrice), 2) AS SpecificAverageSalePrice,
	(SELECT ROUND(AVG(SalePrice), 2) FROM Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning) AS OverallAverageSalePrice
FROM
	Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning
GROUP BY
	LandUse,
	PropertyCity
HAVING 
	Count(LandUse) > 10
ORDER BY
	SpecificAverageSalePrice DESC;

/*
The next query shows the average difference between the sale price and the total value for each specific type of home 
(categorized by land use) in each city, as well as the average difference between the sale price and total value for all homes in the data. 
*/
			 
SELECT 	
	LandUse,
	PropertyCity,
	Count(*) AS Count,
	ROUND(AVG(SalePrice - TotalValue), 2) AS SpecificAverageSalePriceDifference,
	(SELECT ROUND(AVG(SalePrice - TotalValue), 2) FROM Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning) AS OverallAverageSalePriceDifference
FROM
	Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning
GROUP BY
	LandUse,
	PropertyCity
HAVING 
	Count(LandUse) > 10
ORDER BY
	SpecificAverageSalePriceDifference DESC;

/*
The final query shows the average sale price (compared to the overall average sale price) for each combination
of number of bedrooms, number of full bathrooms, and number of half bathrooms.
*/

SELECT 	
	Bedrooms,
	FullBath,
	HalfBath,
	ROUND(AVG(SalePrice), 2) AS SpecificAverageSalePrice,
	(SELECT ROUND(AVG(SalePrice), 2) FROM Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning) AS OverallAverageSalePrice
FROM
	Nashville_Housing.Nashville_Housing_Data_for_Data_Cleaning
GROUP BY
	Bedrooms,
	FullBath,
	HalfBath
HAVING
	COUNT(*) >= 5
ORDER BY
	SpecificAverageSalePrice DESC;

	
