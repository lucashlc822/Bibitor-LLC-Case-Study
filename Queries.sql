/*---------------------------------------------------------------------------------------------------------
------------------------------------------------Queries----------------------------------------------------
---------------------------------------------------------------------------------------------------------*/

-------------------------------------------------Phase 1----------------------------------------------------
/*Total Freight Costs for Transactions greater than $100 with a quantity less than or equal to 1000 units*/
SELECT
VendorNumber as vendor_number,
SUM(freight) as freight_cost
FROM
VendorInvoicesDec
WHERE Dollars > '100'
AND Quantity <= '1000'
GROUP BY VendorNumber
ORDER BY freight_cost DESC
/* Which Vendor Number corresponds to the largest FreightCost under these conditions?*/

/*Create an aggregrate table that includes all crtical vendor billings and their associated purchasing activity. Critical vendors are assumed to have more than $1000 spent.*/
CREATE TABLE TEMP.vendor_purchasing_activity as
SELECT
VendorName,
VendorNumber,
InvoiceDate,
PONumber,
PODate,
PayDate,
Dollars
FROM
VendorInvoicesDec
WHERE
Dollars > 1000

/*Top 10 vendors by quantity*/
CREATE TABLE TEMP.c1_Prep_top10_quantity as
SELECT
VendorName,
VendorNumber,
SUM(Quantity) as total_quantity
FROM
VendorInvoicesDec
GROUP BY VendorName, VendorNumber
ORDER BY total_quantity DESC
LIMIT 10

/*Top 10 vendors by dollars*/
CREATE TABLE TEMP.c1_Prep_top10_dollars as
SELECT
VendorName,
VendorNumber,
SUM(Dollars) as total_dollars
FROM
VendorInvoicesDec
GROUP BY VendorName, VendorNumber
ORDER BY total_dollars DESC
LIMIT 10

/*Find the number of days between a PO is requested and the date the customer pays for the order */
SELECT
PODate,
InvoiceDate,
julianday(InvoiceDate) - julianday(PODate) as delivery_gap,
julianday(PayDate) - julianday(InvoiceDate) as sale_gap
FROM
VendorInvoicesDec
ORDER BY delivery_gap DESC

-------------------------------------------------Phase 2----------------------------------------------------
/* Recalcuulating the Purchase Price assuming the costing method is moving-average cost.*/
CREATE TABLE MovingAverageCostDec AS
SELECT
sq1.Brand,
sq1.Store,
sq1.moving_average_cost,
sq2.onHand,
sq2.City,
sq2.Size,
sq2.Price,
ABS(sq1.moving_average_cost - sq2.Price) as difference
FROM
(
SELECT
Brand,
Store,
SUM(PurchasePrice*Quantity)/SUM(Quantity) as moving_average_cost
FROM
PurchasesDec
WHERE PayDate >= '2016-12-01' AND PayDate <= '2016-12-31'
GROUP BY Brand, Store
ORDER BY Brand DESC, Store DESC) as sq1
INNER JOIN
(
SELECT
Brand,
Store,
Price,
onHand,
City,
Size
FROM
EndInvDec
GROUP BY Brand, Store
ORDER BY Brand desc, Store Desc
) as sq2
ON sq1.Brand = sq2.Brand AND sq1.Store = sq2.Store
ORDER BY sq1.Brand desc, sq1.Store desc

/* Calculate days in inventory for each InventoryID */
CREATE TABLE c2_Prep_days_in_inventory as
SELECT
sq1.InventoryId,
sq1.PurchasePrice,
sq1.total_quantity_purchased,
sq2.start_quantity,
sq2.end_quantity,
sq2.average_inv,
(sq2.average_inv/((sq2.start_quantity + sq1.total_quantity_purchased - sq2.end_quantity)*sq1.PurchasePrice))*365 as days_in_inventory
FROM
(SELECT
InventoryId,
PurchasePrice,
SUM(Quantity) as total_quantity_purchased
FROM
PurchasesDec
GROUP BY InventoryId
) as sq1
INNER JOIN
(SELECT
b.InventoryId,
b.onHand as start_quantity,
e.onHand as end_quantity,
(b.onHand + e.onHand)/CAST(2 as REAL) as average_inv
FROM
BegInvDec b
INNER JOIN
EndInvDec e
ON b.InventoryId = e.InventoryId
GROUP BY b.InventoryId) as sq2
ON sq1.InventoryId = sq2.InventoryId
GROUP BY sq1.InventoryId
ORDER BY days_in_inventory DESC

/* Additional Queries */

--create left outer join temp table
CREATE TABLE Temp.left_outer_Inv as
SELECT a.*
FROM
EndInvDec a
LEFT OUTER JOIN BegInvDec b
ON a.InventoryId = b.InventoryId

-- create inner join temp table
CREATE TABLE TEMP.inner_join_inv as
SELECT
a.*
FROM EndInvDec a
INNER JOIN BegInvDec b
ON a.InventoryId = b.InventoryId

--  between outer join and inner join temp tables
CREATE TABLE TEMP.combined_Inv as
SELECT 
*
FROM Temp.left_outer_Inv
UNION
SELECT
*
FROM Temp.inner_join_inv