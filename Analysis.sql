CREATE DATABASE Vehicles;

USE Vehicles;

-- List the top 3 and bottom 3 makers for the fiscal years 2023 and 2024 in terms of the number of 2-wheelers sold.
   WITH filtered_sales AS (
   SELECT 
        evsm.maker,
        evsm.electric_vehicles_sold,
        dd.fiscal_year
    FROM 
        electric_vehicle_sales_by_makers evsm
    JOIN 
        dim_date dd ON evsm.date = dd.date
    WHERE 
        evsm.vehicle_category = '2-Wheelers'
        AND dd.fiscal_year IN ('2023', '2024')
),
sales_by_maker AS (
    SELECT 
        maker,
        fiscal_year,
        SUM(electric_vehicles_sold) AS total_2wheeler_sales
    FROM 
        filtered_sales
    GROUP BY 
        maker, fiscal_year
),
ranked_sales AS (
    SELECT 
        maker,
        fiscal_year,
        total_2wheeler_sales,
        RANK() OVER (PARTITION BY fiscal_year ORDER BY total_2wheeler_sales DESC) AS rank_desc,
        RANK() OVER (PARTITION BY fiscal_year ORDER BY total_2wheeler_sales ASC) AS rank_asc
    FROM 
        sales_by_maker
)
SELECT 
    fiscal_year,
    maker,
    total_2wheeler_sales,
    rank_desc
FROM 
    ranked_sales
WHERE 
    rank_desc <= 3 OR rank_asc <= 3
ORDER BY 
    fiscal_year, rank_desc;

--  Identify the top 5 states with the highest penetration rate in 2-wheeler  and 4-wheeler EV sales in FY 2024.
SELECT 
	ev.state,
    (sum(ev.electric_vehicles_sold)/sum(ev.total_vehicles_sold))*100 AS penetration_rate
  FROM electric_vehicle_sales_by_state ev
  JOIN dim_date d 
  ON d.date=ev.date
  WHERE vehicle_category="4-Wheelers" and fiscal_year = "2024"
  GROUP BY state
  Order by penetration_rate desc
  LIMIT 5;
  
  SELECT 
	ev.state,
    (sum(ev.electric_vehicles_sold)/sum(ev.total_vehicles_sold))*100 AS penetration_rate
  FROM electric_vehicle_sales_by_state ev
  JOIN dim_date d 
  ON d.date=ev.date
  WHERE vehicle_category="2-Wheelers" and fiscal_year = "2024"
  GROUP BY state
  Order by penetration_rate desc
  LIMIT 5;
  
  -- 3.List the states with negative penetration (decline) in EV sales from 2022 to 2024?
SELECT state, 
	   SUM(CASE WHEN fiscal_year = "2022" THEN electric_vehicles_sold ELSE 0 END) AS sales_2022,
       SUM(CASE WHEN fiscal_year = "2024" THEN electric_vehicles_sold ELSE 0 END) AS sales_2024	
FROM electric_vehicle_sales_by_state ev
JOIN dim_date d ON ev.date = d.date
WHERE fiscal_year IN ("2022", "2024")
GROUP BY state
ORDER BY state;

-- What are the quarterly trends based on sales volume for the top 5 EV makers (4-wheelers) from 2022 to 2024?
WITH top5maker AS
(SELECT
	maker
FROM 
electric_vehicle_sales_by_makers ev
JOIN dim_date d
ON d.date=ev.date
Where vehicle_category="4-Wheelers"
GROUP BY maker
order by sum(electric_vehicles_sold) desc
limit 5)

Select 
	maker,
    fiscal_year,
    quarter,
    sum(electric_vehicles_sold) as total_sales
FROM electric_vehicle_sales_by_makers ev 
JOIN dim_date d 
On d.date=ev.date
WHERE maker in (select maker from top5maker)
group by maker,fiscal_year,quarter
order by maker,fiscal_year,quarter;

-- How do the EV sales and penetration rates in Delhi compare to Karnataka for 2024?
SELECT 
	ev.state,
    (sum(ev.electric_vehicles_sold)/sum(ev.total_vehicles_sold))*100 AS penetration_rate
  FROM electric_vehicle_sales_by_state ev
  JOIN dim_date d 
  ON d.date=ev.date
  WHERE d.fiscal_year = "2024" AND ev.state IN ("Delhi","Karnataka")
  GROUP BY state
  Order by penetration_rate desc;
  
  -- List down the compounded annual growth rate (CAGR) in 4-wheeler units for the top 5 makers from 2022 to 2024.
  WITH top5maker AS
(SELECT 
	maker
FROM electric_vehicle_sales_by_makers ev 
WHERE vehicle_category="4-Wheelers"
GROUP BY maker
ORDER BY sum(electric_vehicles_sold) DESC
LIMIT 5)
SELECT
	maker,
    power((SUM(CASE WHEN d.fiscal_year = "2024" THEN ev.electric_vehicles_sold ELSE 0 END) / 
     SUM(CASE WHEN d.fiscal_year = "2022" THEN ev.electric_vehicles_sold ELSE 0 END)),0.5) - 1 AS CAGR
From electric_vehicle_sales_by_makers ev 
JOIN dim_date d 
ON d.date=ev.date 
WHERE vehicle_category="4-Wheelers" AND maker IN (SELECT maker FROM top5maker)
GROUP BY maker
ORDER BY CAGR DESC;
    
-- List down the top 10 states that had the highest compounded annual growth rate (CAGR) from 2022 to 2024 in total vehicles sold.
WITH ct_2022 AS(
SELECT ev.state, 
       SUM(ev.total_vehicles_sold)  AS Sales_2022
FROM electric_vehicle_sales_by_state ev
JOIN dim_date d ON ev.date = d.date
WHERE d.fiscal_year = "2022"
GROUP BY ev.state),
ct_2024 AS(
SELECT ev.state, 
       SUM(ev.total_vehicles_sold)  AS Sales_2024
FROM electric_vehicle_sales_by_state ev
JOIN dim_date d ON ev.date = d.date
WHERE d.fiscal_year = "2024"
GROUP BY ev.state),
cagr_calculation AS (
    SELECT
        s22.state,
        s22.Sales_2022,
        s24.Sales_2024,
        POWER((s24.Sales_2024/ s22.Sales_2022), (0.5)) - 1 AS cagr
    FROM ct_2022 s22
    JOIN ct_2024 s24 ON s22.state = s24.state
)
SELECT state, cagr
FROM cagr_calculation
ORDER BY cagr DESC
LIMIT 10;

-- What are the peak and low season months for EV sales based on the data from 2022 to 2024?
SELECT MONTHNAME(date) AS Month_, 
       SUM(electric_vehicles_sold)  AS Sales
FROM electric_vehicle_sales_by_state 
GROUP BY MONTHNAME(date)
ORDER BY SUM(electric_vehicles_sold) DESC;

-- What is the projected number of EV sales (including 2-wheelers and 4-wheelers) for the top 10 states by penetration rate in 2030, 
-- based on the compounded annual growth rate (CAGR) from previous years?


WITH t10sp AS
(SELECT 
    state,
    round((sum(electric_vehicles_sold)/sum(total_vehicles_sold))*100,2) as penetration_rate
FROM electric_vehicle_sales_by_state ev 
group by state
order by penetration_rate desc
limit 10),

CAGR_CTE AS
(select
	state,
    round(power((SUM(CASE WHEN d.fiscal_year = "2024" THEN ev.electric_vehicles_sold ELSE 0 END) / 
     SUM(CASE WHEN d.fiscal_year = "2022" THEN ev.electric_vehicles_sold ELSE 0 END)),0.5) - 1,2) AS CAGR
From electric_vehicle_sales_by_state ev 
JOIN dim_date d 
ON d.date=ev.date 
WHERE state in (select state from t10sp)
group by state
Order by CAGR desc),
sales22 AS
(select
	t10sp.state,
    sum(ev.electric_vehicles_sold) as sales_2022
FROM electric_vehicle_sales_by_state ev 
JOIN dim_date d ON d.date=ev.date
JOIN t10sp on ev.state=t10sp.state
WHERE fiscal_year="2022"
group by t10sp.state)

select
	sales22.state,
    sales_2022,
    CAGR_CTE.CAGR,
    round(sales_2022*power(1+ CAGR,8),2) AS projection_2030
from sales22 
JOIN CAGR_CTE ON sales22.state=CAGR_CTE.state
group by state
order by projection_2030 desc;

--  Estimate the revenue growth rate of 4-wheeler and 2-wheelers EVs in India for 2022 vs 2024 and 2023 vs 2024, assuming an average unit price.
SELECT 
	vehicle_category,fiscal_year,
	CASE
		WHEN vehicle_category="2-Wheelers" THEN sum(electric_vehicles_sold*85000)
        ELSE sum(electric_vehicles_sold*1500000)
        END AS revenue
FROM electric_vehicle_sales_by_makers ev 
JOIN dim_date d 
ON d.date=ev.date
group by vehicle_category,fiscal_year
order by vehicle_category,fiscal_year;



    

        