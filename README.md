# calculate-a-hedged-index

Let’s assume that on a daily baisis you calculate and store the total return of an index in some currency, say US 
dollar (USD) terms. With the assumption that the constituents of the index are all denominated in the same currency (ie USD),
you want to create/calculate a new index based on it but hedged in a forward currency 
(e.g HKD) for a specific forward time period e.g 3 months is an industry standard. 
 
We assume we have a database table **INDEX_DHIST** that contains a time series of daily Total Return values for our 
established index in whatever base currency terms e.g US dollars. We also assume we have a daily history of 
both spot and required forward cross rates against our base currency for the required forward 
currency **curr** contained in a database table called **CURR_RATES**

The Oracle PL/SQL in this repository shows the calculation required. It should be reasonably starightforward to convert to 
other database systems and languages. The structure of our database tables are as follows:-

**INDEX_DHIST**

* I_MNEM VARCHAR(7)  // 7 character index identifier or whatever you want this to be   
* X_DATE DATE        // The index value date   
* I_VAL NUMBER       // The index value itself 


**CURR_RATES**
 
* C_MNEM   VARCHAR2(3)  // 3 character currency mnemonic or whatever you want this to be 
* CF_DATE  DATE         // cross rate date 
* CF_TERM  VARCHAR2(2)  // 1M, 3M etc  
* CF_XRATE NUMBER       // the cross rate itself 
