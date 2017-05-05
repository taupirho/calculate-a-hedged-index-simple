# calculate-a-hedged-index

Let’s assume that on a daily baisis you calculate the total return of an index in US dollar (USD) terms. You now want 
to create/calculate a new index based on it but hedged in a forward currency (e.g HKD) over a specific time 
period e.g 3mths is an industry standard. 
 
We assume we have a database table **INDEX_DHIST** that contains a time series of daily USD Total Return values for our 
established index. We also assume we have a daily history of both spot and required forward cross rates for the required 
forward currency **curr** contained in a database table called **USD_RATES

The Oracle PL/SQL in this repository shows the calculation required. It should be reasonably starightforward to convert to 
other database systems and languages
 
