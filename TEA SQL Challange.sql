/**************************************
Challenge 1: The leadership team has asked us to graph total monthly sales over time. Write a query that returns the data we need to complete this request.
**************************************/

select
datepart(year,I.invoicedate) InvoiceYr
, datepart(month, I.InvoiceDate) InvoiceMonth
, datename(month, InvoiceDate) InvoiceMonthName
, Sum(LineProfit) Revenue
from [Sales].[InvoiceLines] il
inner join [Sales].[Invoices] i on il.InvoiceID = i.InvoiceID
group by datepart(year,I.invoicedate), datepart(month, I.InvoiceDate), datename(month, InvoiceDate) 
order by datepart(year,I.invoicedate), datepart(month, I.InvoiceDate)




/**************************************
Challenge 2: What is the fastest growing customer category in Q1 2016 (compared to same quarter sales in the previous year)? What is the growth rate?
**************************************/
declare @year int = 2016
declare @quarter int = 1

Select 
A.*
, B.Transactions PreviousTransactions
, (cast((A.Transactions-B.Transactions) as float)/cast(B.Transactions as float)) * 100 [GrowthPercent]
from (select 
	cc.CustomerCategoryName
	,datepart(year,ct.TransactionDate) TransactionYear
	,datepart(qq, ct.TransactionDate) TransactionQuarter
	, count(ct.CustomerTransactionID) Transactions
	from (select * from [Sales].[CustomerTransactions] 
		 where datepart(year,TransactionDate) = @year
		 and datepart(qq, TransactionDate) = @quarter) ct
	inner join Sales.Customers c on ct.CustomerID = c.CustomerID and ct.IsFinalized = 1
	inner join Sales.CustomerCategories cc on c.CustomerCategoryID = cc.CustomerCategoryID
	group by cc.CustomerCategoryName,datepart(year,ct.TransactionDate),datepart(qq, ct.TransactionDate)) A
left outer join (select 
				cc.CustomerCategoryName
				,datepart(year,ct.TransactionDate) TransactionYear
				,datepart(qq, ct.TransactionDate) TransactionQuarter
				, count(ct.CustomerTransactionID) Transactions
				from (select * from [Sales].[CustomerTransactions] 
						where datepart(year,TransactionDate) = @year - 1
						and datepart(qq, TransactionDate) = @quarter) ct
				inner join Sales.Customers c on ct.CustomerID = c.CustomerID and ct.IsFinalized = 1
				inner join Sales.CustomerCategories cc on c.CustomerCategoryID = cc.CustomerCategoryID
				group by cc.CustomerCategoryName,datepart(year,ct.TransactionDate),datepart(qq, ct.TransactionDate)) B on B.CustomerCategoryName = A.CustomerCategoryName



------ Computer Store is the fastest growing customer category of Q1 of 2016 with a growth rate of 22.2%

/**************************************
Challenge 3: Write a query to return the list of suppliers that WWI has purchased from, along with # of invoices paid, # of invoices still outstanding, and average invoice amount.
**************************************/

select 
s.SupplierID
, s.SupplierName
, isnull(st1.Transactions,0) InvoicesPaid
, isnull(st2.Transactions,0) InvoicesOutstanding
, isnull(avg(st3.InvoiceAmount),0) AvgInvoiceAmount
from [Purchasing].[Suppliers] s
left outer join  (select SupplierID, count(SupplierTransactionID) Transactions
				from [Purchasing].[SupplierTransactions] 
				where TransactionTypeID = 7
				group by SupplierID) st1 on s.SupplierID = st1.SupplierID
left outer join  (select SupplierID, count(SupplierTransactionID) Transactions
				from [Purchasing].[SupplierTransactions] 
				where OutstandingBalance <> 0
				and TransactionTypeID = 5
				group by SupplierID) st2 on s.SupplierID = st2.SupplierID
left outer join  (select SupplierID, SupplierInvoiceNumber, sum(TransactionAmount) InvoiceAmount
				from [Purchasing].[SupplierTransactions] 
				where TransactionAmount > 0
				and  TransactionTypeID = 5
				group by SupplierID, SupplierInvoiceNumber) st3 on s.SupplierID = st3.SupplierID
group by s.SupplierID, s.SupplierName, isnull(st1.Transactions,0), isnull(st2.Transactions,0)


/**************************************
Challenge 4: Considering sales volume, which item in the warehouse has the lowest gross profit amount? Which item has the highest? What is the median gross profit across all items in the warehouse?
**************************************/
IF OBJECT_ID('tempdb..#Results') IS NOT NULL
DROP TABLE #Results

create table #Results
(StockItemID int
, StockItemName varchar(100)
, LastCostPrice decimal(18,2)
, UnitPrice decimal(18,2)
, SalesQuantity int
, SalesAmount decimal(18,2)
, GrossProfit decimal(18,2)
)

insert into #Results (StockItemID, StockItemName, LastCostPrice, UnitPrice, SalesQuantity, SalesAmount, GrossProfit) 
select A.*
from (SELECT
	SI.StockItemID
	, SI.StockItemName
	, sih.LastCostPrice
	, si.UnitPrice
	, SalesQuantity
	, ol.SalesAmount
	, ol.SalesAmount - (sih.LastCostPrice*ol.SalesQuantity) GrossProfit
	FROM [Warehouse].[StockItems] SI
	inner join [Warehouse].[StockItemHoldings] sih on sih.StockItemID = si.StockItemID
	left outer join (select StockItemID, Sum(PickedQuantity) SalesQuantity, Sum(PickedQuantity*UnitPrice) SalesAmount
					from [Sales].[OrderLines]
					group by StockItemID) ol on si.StockItemID = ol.StockItemID) A


Select top 1 * from #Results order by GrossProfit asc
---- Halloween zombie mask (Light Brown) XL has the lowest gross profit with -$72,372.00 in sales.


Select top 1 * from #Results order by GrossProfit desc
---- 20 mm Double sided bubble wrap 50m has the highest gross profit making $5,293,680.00 in sales.


SELECT
(
 (SELECT MAX(GrossProfit) FROM
   (SELECT TOP 50 PERCENT GrossProfit FROM #Results ORDER BY GrossProfit) AS BottomHalf)
 +
 (SELECT MIN(GrossProfit) FROM
   (SELECT TOP 50 PERCENT GrossProfit FROM #Results ORDER BY GrossProfit DESC) AS TopHalf)
) / 2 AS Median
---- Median gross profit across all items in the warehouse is $136,485.00


drop table #Results