/*
 *
 * Calculate the hedged  total return (TR) of a portfolio/index based on a  forward  
 * rate (fwd_term) of currency ( curr )
 *
 * Hedged Total Return  = prev end of period hedged Total Return x  Hedge Return
 *
 * We get prev end of period Hedged Total Return from the index_dhist table and     
 * we calculate hedge return where ....
 *
 * hedge return = unhedged index performance in currency curr + hedged   
 * currency performance
 *
 * unhedged performance in currency curr =
 * (TR for current date/fx spot rate at current date)/
 * (TR for prev date/fx spot at previous date)
 *
 * where TR is the Total return
 *
 * hedged currency performance =
 * (prev end of period spot cross rate/prevend_of_periodfwd cross rate)  -
 * (prev end of_period spot cross rate/((current spot  cross rate) + D *
 * (current fwd cross rate - current spot cross rate)))
 *
 * and D = (days left in period/total days in period)
 */
 
create or replace procedure hedge_portfolio
(
   the_date IN varchar2,     -- normally todays date
   mnem IN varchar2,         -- identifier of the index/portfolio you want to hedge
   mnem_hedge IN varchar2,   -- identifier of the calculated hedge index/portfolio
   curr IN varchar2,         -- forward currency you are using to hedge e.g HKD
   fwd_term IN varchar2,     -- the fwrd rate we are using e.g  3 Mth, 1 Mth etc..
   update_db IN boolean := false,      -- do we update the database with our new index value
   hedge_capital IN boolean := false,  -- do we calculate/update the capital return also
   debug IN boolean := false           -- do we output debug message
)
is

   tot_ret_unhedged number := 0 ;
   cap_ret_unhedged number := 0 ;
   hedged_tr_index_prev number := 0 ;
   hedged_cr_index_prev number := 0 ;
   bx_mnem varchar2(7) := null;
   current_xrate number := 0;
   current_fwd_xrate number := 0;
   prev_xrate number := 0;
   prev_fwd_xrate number := 0;
   prev_date date := null ;
   bigD number := 0;
   currency_return number := 0;
   hedged_return_tr number := 0;
   hedged_return_cr number := 0 ;
   hedged_tr_index number := 0 ;
   hedged_cr_index number := 0 ;
   period_frac number := 0 ;
   smallD number := 0 ;
   pdate date := null;
   period number := 0 ;
   trunc_param varchar2(4) := null ;
 
begin
 
   selectto_date(the_date,'yyyymmdd')
   into pdate from dual;
 
   dbms_output.put_line(' Current Date : ' || pdate ) ;
 
   select decode(fwd_term,'3M','q','1M','MON','1W','WW','3M')
   into trunc_param from dual;
 
   dbms_output.put_line(' Date truncparam : ' || trunc_param ) ;
 
   select decode(fwd_term,'3M',3,'1M',1,'1W',7,3)
   into period from dual;
 
   dbms_output.put_line(' Forward Period : ' || period ) ;
 
   /* depending on what fwd rate term we are using, get the end period
      3 months, 1 month ago etc…
    */
   select trunc(pdate,trunc_param) - 1 - decode(to_char(trunc(pdate,trunc_param)-1,'DY'),'SAT',1,'SUN'
   into prev_date from dual ;
 
   if debug = true then
 
      dbms_output.put_line(' Current Date : ' || pdate ) ;
      dbms_output.put_line(' Date truncparam : ' || trunc_param ) ;
      dbms_output.put_line(' Forward Period : ' || period ) ;
      dbms_output.put_line(' Previous end of period date :' || prev_date ) ;
   end if;
 
   /* get the unhedged performance in currency curr */
 
   select
      ((b1.x_trval/b2.x_trval) * (h2.c_xrate/h1.c_xrate))
      ((b1.x_cpval/b2.x_cpval) * (h2.c_xrate/h1.c_xrate))
   into tot_ret_unhedged, tot_cap_unhedged
   from index_dhist b1,index_dhist b2 , curr_rates h1,curr_rates h2
   where b1.bx_mnem = b2.bx_mnem
   and b1.x_date = pdate
   and h1.c_date = b1.x_date
   and b2.x_date = prev_date
   and h2.c_date = b2.x_date
   and h1.currency = h2.currency
   and h1.currency = curr
   and b1.bx_mnem = mnem ;
 
 
   if debug = true then
 
      dbms_output.put_line(' Current UNHEDGED TR:DATE ' || tot_ret_unhedged || ',' || pdate);
      dbms_output.put_line(' Current UNHEDGED CR:DATE ' || cap_ret_unhedged || ',' || pdate);
      dbms_output.put_line(' Current SPT XRATE:DATE ' || current_xrate || ',' || pdate);
      dbms_output.put_line(' Current FWD XRATE:DATE ' || current_fwd_xrate || ',' || pdate);
   end if;
 
   /* Now use PREV_DATE to get prev period hedged TR  */
 
   /* First get TR in currency curr for date pdate */
   for c1_rec in
   (
      select h1.c_xrate,u.cf_xrate c_xrate2
      from  curr_rates h1, curr_rates u
      where h1.currency = u.c_mnem
      and u.cf_term = fwd_term
      and u.cf_date = h1.c_date
      and u.cf_date = prev_date
      and u.c_mnem = curr
   )
   loop
      prev_xrate := c1_rec.c_xrate;
      prev_fwd_xrate := c1_rec.c_xrate2;
   end loop;
 
   if debug = true then
 
      dbms_output.put_line('Previous SPT XRATE:DATE ' || prev_xrate || ',' || prev_date);
      dbms_output.put_line('Previous FWD XRATE:DATE ' || prev_fwd_xrate || ',' || prev_date);
 
   end if ;
 
   for c1_rec in
   (
      selectx_trval,nvl(x_cpval ,0) x_cpval
      from index_dhist
      where x_date = prev_date
      and bx_mnem = mnem_hedge
   )
   loop
      hedged_tr_index_prev := c1_rec.x_trval ;
      hedged_cr_index_prev := c1_rec.x_cpval ;
   end loop;
 
   if debug = true then
 
      dbms_output.put_line(' Prev Period HEDGED TR:DATE ' || hedged_tr_index_prev || ',' || prev_date)
      dbms_output.put_line(' Prev Period HEDGED CR:DATE ' || hedged_cr_index_prev || ',' || prev_date)
 
   end if;
 
   /* Calculate big D = the days remaining in the period/ total days in period*/
 
   for c1_rec in
   (
      select smalld/bigdperiod_frac,smalld , bigd
      from
      (
         SELECT
            (add_months(trunc(pdate, trunc_param), period) -1) -
            (trunc(pdate,trunc_param) -1) bigd,
            (add_months(trunc(pdate, trunc_param), period) -1) - (trunc(pdate)) smalld
         FROM dual
      )
   )
   loop
      bigD := c1_rec.bigd ; -- total nr days in period
      period_frac := c1_rec.period_frac ;
      smallD := c1_rec.smalld ; -- nr days left in period
   end loop;
 
   if debug = true then
 
      dbms_output.put_line(' Big D = ' || bigD ) ;
      dbms_output.put_line(' Small D = ' || smallD );
      dbms_output.put_line(' Period Frac = ' || period_frac );
 
   end if;
 
   /* Hedged  Currency performance */
 
   /*
    * currency_performance :=
    * ((1/prev_xrate)/(1/prev_fwd_xrate)) -
    * ((1/prev_xrate)/(((1/current_xrate)) + bigD*((1/current_fwd_xrate)-(1/current_xrate))));
    */
 
   currency_return := (prev_xrate/prev_fwd_xrate) - (prev_xrate/( current_xrate + period_frac *
   (current_fwd_xrate - current_xrate))) ;
 
   /* hedged return = unhedged index perf in currency curr  + currency return */
 
   hedged_return_tr := tot_ret_unhedged + currency_return ;
 
   hedged_return_cr := cap_ret_unhedged + currency_return ;
 
   /* hedged total return = current hedged return * prev end of period hedged return */
 
   hedged_tr_index := hedged_tr_index_prev *  hedged_return_tr  ;
 
   hedged_cr_index := hedged_cr_index_prev *  hedged_return_cr  ;
 
   if debug = true then
 
      dbms_output.put_line('currency return = ' || currency_return) ;
      dbms_output.put_line('hedged return (TR) = ' || hedged_return_tr) ;
      dbms_output.put_line('hedged return (CR) = ' || hedged_return_cr) ;
      dbms_output.put_line('hedged Total Return Index = ' || hedged_tr_index) ;
      dbms_output.put_line('hedged Capital Return Index = ' || hedged_cr_index) ;
 
   end if;
 
   if update_db = true then
 
      if hedge_capital= true then
 
           delete from index_dhist where bx_mnem = mnem_hedge
           and x_date = pdate ;
 
           insert into index_dhist(bx_mnem,x_date,x_trval,x_cpval)
           select mnem_hedge,pdate,hedged_tr_index,hedged_cr_index
           from dual;
 
           commit;
 
       else
          delete from index_dhist where bx_mnem = mnem_hedge
          and x_date = pdate ;
 
          insert into index_dhist(bx_mnem, x_date , x_trval)
          selectmnem_hedge, pdate ,hedged_tr_index from dual;
 
          commit;
 
       end if ;
 
   end if;
 
end;
/
show err
exit
