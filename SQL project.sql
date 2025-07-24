use chinook;
/* 

OBJECTIVE QUESTIONS

*/
/* 1.	Does any table have missing values or duplicates? If yes, how would you handle it? */

select * from album;
select distinct * from album; -- No duplicates

SELECT * FROM artist;
SELECT distinct * FROM artist; -- No duplicates

SELECT * from customer;
SELECT distinct * FROM customer; -- No duplicates
SELECT COUNT(*) FROM customer;
 -- WHERE fax is NULL; ( count = 47)
-- WHERE state is NULL;(count = 29)
-- WHERE company is NULL; (count = 49)
-- WHERE phone is NULL (count =1);
-- 47 fax, 29 state and 49 company values are null in the customer table

SELECT * from employee; -- 1 reports_to value is null for employee_id = 1
SELECT distinct * FROM employee; -- No duplicates

SELECT * FROM genre;
SELECT distinct * FROM genre; -- No duplicates

SELECT * FROM invoice;
SELECT distinct * FROM invoice; -- No duplicates

SELECT * FROM invoice_line;
SELECT distinct * FROM invoice_line; -- No duplicates

SELECT * FROM media_type;
SELECT distinct * FROM media_type; -- No duplicates

SELECT * FROM playlist;
SELECT distinct * FROM playlist; -- No duplicates

SELECT * FROM playlist_track;
SELECT distinct * FROM playlist_track;

SELECT * FROM track;
SELECT distinct * FROM track; -- No duplicates

SELECT COUNT(*) FROM track 
WHERE composer is NULL; -- 978 composers are not assigned any value/are null in the track table

UPDATE customer SET company = 'Unknown' WHERE company IS NULL; -- 49 row(s) affected
UPDATE customer SET state = 'None' WHERE state IS NULL; -- 29 row(s) affected
UPDATE customer SET phone = '+0 000 000 0000' WHERE phone IS NULL; -- 1 row(s) affected
UPDATE customer SET fax = '+0 000 000 0000' WHERE fax IS NULL; -- 47 row(s) affected
UPDATE track SET composer = 'Unknown' WHERE composer IS NULL; -- 978 row(s) affected

/*
The data provided possess 0 duplicates although there are missing values in 3 tables
which could be handled by using the coalesce function
*/
-- ---------------------------------------------------------------------------------------------------------------------------------------- 

/*  2.	Find the top-selling tracks and top artist in the USA and identify their most famous genres.*/

select t.name as Track_name,
a.name as artist_name,
g.name as genre_name,
sum(i.total) as total_sales,
RANK() OVER(ORDER BY SUM(i.total) DESC) AS sales_rank
from track t
 join invoice_line il on il.track_id = t.track_id
 join invoice i on i.invoice_id = il.invoice_id
 join album al on al.album_id = t.album_id
join artist a on a.artist_id = al.artist_id
join genre g on t.genre_id = g.genre_id
where i.billing_country = 'USA'
group by t.name,a.name,g.name
order by sum(total) desc
LIMIT 10;

-- ------------------------------------------------------------------------------------------------------------------------------------------------
/* 3.	What is the customer demographic breakdown (age, gender, location) of Chinook's customer base? */

select city,
coalesce (state,"Unknown") as state,
country,
count(customer_id) as customer_count
from customer
group by country,state,city
order by country;

-- ----------------------------------------------------------------------------------------------------------------------------------------
/* 4.	Calculate the total revenue and number of invoices for each country, state, and city: */
select billing_country as country,
billing_state as state,
billing_city as city,
count(invoice_id) as no_of_invoices,
sum(total) as Total_revenue
from invoice
group by country,state,city
order by count(invoice_id) desc, sum(total) desc;

-- ---------------------------------------------------------------------------------------------------------------------------------------------
/* 5.	Find the top 5 customers by total revenue in each country */

WITH Top5CustomersCountryWise AS (
	SELECT 
		c.country, 
        CONCAT(c.first_name,' ',c.last_name) AS customer,
        SUM(i.total) AS total_revenue,
        RANK() OVER(PARTITION BY c.country ORDER BY SUM(i.total) DESC) AS countrywiseRank
	FROM customer c JOIN invoice i ON c.customer_id = i.customer_id
	GROUP BY c.country,c.first_name,c.last_name
)

SELECT 
	country,
    customer,
    total_revenue,
    countrywiseRank
FROM Top5CustomersCountryWise
WHERE countryWiseRank <= 5
ORDER BY country,total_revenue DESC;

-- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

/* 6.	Identify the top-selling track for each customer */

select concat(c.first_name,' ',c.last_name) as Full_name, t.name as Track_name, SUM(quantity) as Total_quantity,
SUM(i.total) AS total_sales
from customer c
left join invoice i on i.customer_id = c.customer_id
left join invoice_line il on il.invoice_id = i.invoice_id
left join track t on t.track_id = il.track_id
group by concat(c.first_name,' ',c.last_name),t.name
ORDER BY SUM(quantity) DESC;

-- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 7.	Are there any patterns or trends in customer purchasing behaviour (e.g., frequency of purchases, preferred payment methods, average order value)? */

WITH InvoiceMetrics AS (
    SELECT
	    c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        i.invoice_date,
        DATEDIFF(
            LEAD(i.invoice_date) OVER (PARTITION BY c.customer_id ORDER BY i.invoice_date),
            i.invoice_date
        ) AS days_between_purchases,
        i.total
    FROM
        customer c
    JOIN
        invoice i ON c.customer_id = i.customer_id
),
CustomerStats AS (
    SELECT
        customer_id,
        customer_name,
        COUNT(*) AS total_purchases,
        AVG(days_between_purchases) AS avg_days_between_purchases,
        SUM(total) AS total_spent,
        AVG(total) AS avg_order_value,
        MAX(total) AS max_order_value,
        MIN(total) AS min_order_value
    FROM
        InvoiceMetrics
    GROUP BY
        customer_id, customer_name
)
SELECT
    customer_id,
    customer_name,
    total_purchases,
    avg_days_between_purchases,
    total_spent,
    avg_order_value,
    max_order_value,
    min_order_value
FROM
    CustomerStats
WHERE
    total_spent > 0
ORDER BY
    avg_days_between_purchases ASC,
    total_spent DESC,
    total_purchases DESC;


/*
No there is no correlation or trend between the number/frequency of orders by different customers and the 
average sales generated by these customers.
The average sales most probably depends on the unit price of each track and not he number of orders.
*/ 

-- -----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 8.	What is the customer churn rate? */

WITH PreviousCustomerPurchases AS (
    SELECT 
        c.customer_id,c.first_name,c.last_name,DATE(i.invoice_date) AS invoice_date,
        LEAD(DATE(i.invoice_date)) OVER(PARTITION BY c.customer_id ORDER BY invoice_date DESC) AS prev_purchase
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
),

PrevPurchaseRank AS (
	SELECT 
		*,ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY prev_purchase DESC) AS prev_purchase_rn
	FROM PreviousCustomerPurchases
),

PreviousPurchaseDate AS (
	SELECT 
		*,DATEDIFF(invoice_date,prev_purchase) AS days_since_last_purchase
	FROM PrevPurchaseRank
	WHERE prev_purchase_rn = 1
	AND DATEDIFF(invoice_date,prev_purchase) > 180
	ORDER BY days_since_last_purchase DESC
)

SELECT 
	COUNT(pp.customer_id) AS churned_customers,
    COUNT(c.customer_id) AS total_customers,
    ROUND((COUNT(pp.customer_id) * 100) / COUNT(c.customer_id), 2) AS churn_rate
FROM customer c LEFT JOIN PreviousPurchaseDate pp ON c.customer_id = pp.customer_id;

-- -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 9.	Calculate the percentage of total sales contributed by each genre in the USA and identify the
 best-selling genres and artists.*/
 
 WITH SalesGenreRankUSA AS (
	SELECT
		g.name AS genre, ar.name AS artist, SUM(i.total) AS genre_sales,
        DENSE_RANK() OVER( PARTITION BY g.name ORDER BY SUM(i.total) DESC) AS genre_rank	
	FROM genre g
    LEFT JOIN track t ON g.genre_id = t.genre_id
    LEFT JOIN invoice_line il ON t.track_id = il.track_id
    LEFT JOIN invoice i ON il.invoice_id = i.invoice_id
    LEFT JOIN album a ON t.album_id = a.album_id
    LEFT JOIN artist ar ON a.artist_id = ar.artist_id
    WHERE i.billing_country = 'USA'
    GROUP BY 1,2
),

TotalSalesUSA AS (
	SELECT 
		SUM(i.total) AS total_sales
	FROM invoice_line il 
    LEFT JOIN invoice i ON il.invoice_id = i.invoice_id
    WHERE i.billing_country = 'USA'
)

SELECT s.genre,s.artist,s.genre_sales,t.total_sales, ROUND((s.genre_sales / t.total_sales)* 100,2) AS percent_sales
FROM SalesGenreRankUSA s JOIN TotalSalesUSA t
ORDER BY s.genre_sales DESC, s.genre ASC LIMIT 1;
 
-- ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 10.	Find customers who have purchased tracks from at least 3 different genres */

SELECT 
	c.customer_id,
	CONCAT(c.first_name,' ',c.last_name) AS customer,
	COUNT(DISTINCT t.genre_id) AS genre_count,
	COUNT(DISTINCT t.track_id) AS track_count
	FROM customer c
	JOIN invoice i ON c.customer_id = i.customer_id
	JOIN invoice_line il ON i.invoice_id = il.invoice_id
	JOIN track t ON il.track_id = t.track_id
	JOIN genre g ON t.genre_id = g.genre_id
GROUP BY c.customer_id,c.first_name,c.last_name
HAVING COUNT(DISTINCT g.genre_id) >=3
ORDER BY genre_count DESC;

-- ----------------------------------------------------------------------------------------------------------------------------------------------
/* 11.	Rank genres based on their sales performance in the USA */

WITH SalesWiseGenreRank AS (
	SELECT
		g.name AS genre,
        SUM(i.total) AS total_sales,
        DENSE_RANK() OVER(ORDER BY SUM(i.total) DESC) AS genre_rank	
	FROM genre g
    LEFT JOIN track t ON g.genre_id = t.genre_id
    LEFT JOIN invoice_line il ON t.track_id = il.track_id
    LEFT JOIN invoice i ON il.invoice_id = i.invoice_id
    WHERE i.billing_country = 'USA'
    GROUP BY g.name
)    

SELECT
	genre,total_sales,genre_rank
FROM SalesWiseGenreRank
ORDER BY genre_rank;

-- ------------------------------------------------------------------------------------------------------------------------------------------------------
/* 12.	Identify customers who have not made a purchase in the last 3 months */

WITH CustomerLastPurchase AS (
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
        MIN(DATE(i.invoice_date)) AS first_purchase_date,
        MAX(DATE(i.invoice_date)) AS last_purchase_date
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name
),
CustomerPurchases AS (
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
        DATE(i.invoice_date) AS invoice_date
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
)
SELECT 
    clp.customer_id, 
    clp.first_name, 
    clp.last_name, 
    clp.first_purchase_date,
    clp.last_purchase_date
FROM CustomerLastPurchase clp
LEFT JOIN CustomerPurchases cp ON clp.customer_id = cp.customer_id 
AND cp.invoice_date BETWEEN clp.last_purchase_date - INTERVAL 3 MONTH AND clp.last_purchase_date - INTERVAL 1 DAY
WHERE cp.invoice_date IS NULL
ORDER BY clp.customer_id;


-- --------------------------------------------------------------------------------------------------------------------------------------------------


/*

SUBJECTIVE QUESTIONS

*/


/*1. Recommend the three albums from the new record label that should be prioritised for advertising and 
promotion in the USA based on genre sales analysis.*/

WITH RecommendedAlbums AS (
    SELECT 
		al.title AS album_name,
		a.name AS artist_name,
        g.name AS genre_name,
		SUM(i.total) AS total_sales,
        SUM(il.quantity) AS total_quantity,
		ROW_NUMBER() OVER(ORDER BY SUM(i.total) DESC) AS sales_rank
    FROM customer c 
    JOIN invoice i ON c.customer_id = i.customer_id
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN album al ON t.album_id = al.album_id
    JOIN artist a ON al.artist_id = a.artist_id
    JOIN genre g ON t.genre_id = g.genre_id
    WHERE c.country = 'USA'
    GROUP BY al.title,a.name,g.name
)

SELECT * FROM RecommendedAlbums 
ORDER BY total_sales DESC
limit 3;

-- ------------------------------------------------------------------------------------------------------------------------------------------

/*2. Determine the top-selling genres in countries other than the USA and identify any commonalities or differences.*/

SELECT  
    g.genre_id, 
    g.name, 
    SUM(t.unit_price * il.quantity) AS total_revenue_for_genre,
    SUM(il.quantity) AS total_tracks_sold,
    COUNT(DISTINCT i.invoice_id) AS total_invoices
FROM 
    track t
LEFT JOIN 
    genre g ON g.genre_id = t.genre_id
LEFT JOIN 
    invoice_line il ON il.track_id = t.track_id
LEFT JOIN 
    invoice i ON i.invoice_id = il.invoice_id
WHERE 
    billing_country != 'USA'
GROUP BY 
    g.genre_id, g.name
ORDER BY 
    total_revenue_for_genre DESC;
-- ------------------------------------------------------------------------------------------------------------------------------------------

/*3. Customer Purchasing Behavior Analysis: How do the purchasing habits (frequency, basket size, spending amount) of long-term customers differ from those of new customers? What insights can these patterns provide about customer loyalty and retention strategies? */

WITH cte as
(
SELECT i.customer_id, 
	MAX(invoice_date), MIN(invoice_date), 
	abs(TIMESTAMPDIFF(MONTH, MAX(invoice_date), 
	MIN(invoice_date))) time_for_each_customer, 
	SUM(total) sales, SUM(quantity) items, 
	COUNT(invoice_date) frequency FROM invoice i
LEFT JOIN customer c on c.customer_id = i.customer_id
LEFT JOIN invoice_line il on il.invoice_id = i.invoice_id
GROUP BY 1
ORDER BY time_for_each_customer DESC
),
average_time as
(
SELECT AVG(time_for_each_customer) average FROM cte
),-- 1244.3220 Days OR 40.36 Months
categorization as
(
SELECT *,
CASE
WHEN time_for_each_customer > (SELECT average from average_time) THEN "Long-term Customer" ELSE "Short-term Customer" 
END category
FROM cte
)
SELECT category, SUM(sales) total_spending, SUM(items) basket_size, COUNT(frequency) frequency FROM categorization
GROUP BY 1 ;



-- ------------------------------------------------------------------------------------------------------------------------------------------

/*4. Product Affinity Analysis: Which music genres, artists, or albums are frequently purchased together by customers? How can this information guide product recommendations and cross-selling initiatives? */

WITH ProductAffinityAnalysis AS (
	SELECT 
		c.customer_id,c.first_name,c.last_name,a.name AS artist_name,g.name AS genre_name,
        SUM(il.quantity) AS total_quantity,SUM(i.total) AS total_sales
        -- ,RANK() OVER(ORDER BY SUM(i.total) DESC) AS sales_rank
	FROM invoice i 
    LEFT JOIN invoice_line il ON i.invoice_id = il.invoice_id
    LEFT JOIN track t ON il.track_id = t.track_id
    LEFT JOIN album al ON t.album_id = al.album_id
    LEFT JOIN artist a ON al.artist_id = a.artist_id
    LEFT JOIN genre g ON t.genre_id = g.genre_id
    LEFT JOIN customer c ON i.customer_id = c.customer_id
	GROUP BY c.customer_id,c.first_name,c.last_name,a.name,g.name
)
SELECT * FROM ProductAffinityAnalysis 
ORDER BY customer_id, total_quantity DESC;


-- ------------------------------------------------------------------------------------------------------------------------------------------

/*5. Regional Market Analysis: Do customer purchasing behaviors and churn rates vary across different geographic regions or store locations? How might these correlate with local demographic or economic factors? */

WITH PreviousCustomerPurchases AS (
    SELECT c.country,c.customer_id,c.first_name,c.last_name,DATE(i.invoice_date) AS invoice_date,
        LEAD(DATE(i.invoice_date)) OVER(PARTITION BY c.customer_id ORDER BY invoice_date DESC) AS prev_purchase
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id),
PrevPurchaseRank AS (
	SELECT *,ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY prev_purchase DESC) AS prev_purchase_rn
	FROM PreviousCustomerPurchases),
PreviousPurchaseDate AS (
	SELECT *,DATEDIFF(invoice_date,prev_purchase) AS days_since_last_purchase
	FROM PrevPurchaseRank
	WHERE prev_purchase_rn = 1
	AND DATEDIFF(invoice_date,prev_purchase) > 180
	ORDER BY days_since_last_purchase DESC)
SELECT c.country,
	COUNT(pp.customer_id) AS churned_customers,
    COUNT(c.customer_id) AS total_customers,
    ROUND((COUNT(pp.customer_id) * 100) / COUNT(c.customer_id), 2) AS churn_rate
FROM customer c LEFT JOIN PreviousPurchaseDate pp ON c.customer_id = pp.customer_id
GROUP BY c.country;


-- ------------------------------------------------------------------------------------------------------------------------------------------

/*6. Customer Risk Profiling: Based on customer profiles (age, gender, location, purchase history), 
which customer segments are more likely to churn or pose a higher risk of reduced spending? What 
factors contribute to this risk? */


SELECT i.customer_id, 
CONCAT(first_name, " ", last_name) name, 
billing_country, invoice_date, 
SUM(total) total_spending, 
COUNT(invoice_id) num_of_orders FROM invoice i
LEFT JOIN customer c on c.customer_id = i.customer_id
GROUP BY 1,2,3,4
ORDER BY name;

-- ------------------------------------------------------------------------------------------------------------------------------------------

/*7. Customer Lifetime Value Modeling: How can you leverage customer data (tenure, purchase history, engagement) to predict the lifetime value of different customer segments? This could inform targeted marketing and loyalty program strategies. Can you observe any common characteristics or purchase patterns among customers who have stopped purchasing? */

WITH CustomerTenure AS (
    SELECT 
        c.customer_id, CONCAT(c.first_name,' ', c.last_name) AS customer,
        MIN(i.invoice_date) AS first_purchase_date,
        MAX(i.invoice_date) AS last_purchase_date,
        DATEDIFF(MAX(i.invoice_date), MIN(i.invoice_date)) AS tenure_days,
        COUNT(i.invoice_id) AS purchase_frequency,
        SUM(i.total) AS total_spent
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.customer_id
)
SELECT 
    customer_id,
    customer,
    tenure_days,
    purchase_frequency,
    total_spent,
    ROUND(total_spent / purchase_frequency, 2) AS avg_order_value,
    DATEDIFF(CURRENT_DATE, last_purchase_date) AS days_since_last_purchase
FROM CustomerTenure
ORDER BY days_since_last_purchase DESC;    

-- ------------------------------------------------------------------------------------------------------------------------------------------

/*10. How can you alter the "Albums" table to add a new column named "ReleaseYear" of type INTEGER to store the release year of each album? */

ALTER TABLE album 
ADD COLUMN ReleaseYear INT(4);

SELECT * FROM album;

-- ------------------------------------------------------------------------------------------------------------------------------------------

/*11. Chinook is interested in understanding the purchasing behavior of customers based on their geographical location. They want to know the average total amount spent by customers from each country, along with the number of customers and the average number of tracks purchased per customer. Write a SQL query to provide this information. */

SELECT 
    c.country,
    ROUND(AVG(track_count)) AS average_tracks_per_customer,
    SUM(i.total) AS total_spent,
    COUNT(DISTINCT c.customer_id) AS no_of_customers,
    ROUND(SUM(i.total)/ COUNT(DISTINCT c.customer_id),2) AS avg_total_spent
    
FROM customer c
JOIN invoice i ON c.customer_id = i.customer_id
JOIN (
        SELECT 
            invoice_id, 
            COUNT(track_id) AS track_count
        FROM invoice_line
        GROUP BY invoice_id
) il ON i.invoice_id = il.invoice_id
GROUP BY c.country
ORDER BY avg_total_spent DESC;

-- ------------------------------------------------------------------------------------------------------------------------------------------


