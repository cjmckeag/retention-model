

create view kings.vw_retention_data as

with a as (
select distinct archticsaccountid
from ro.vw_factticketsalesbase
where itemcode like '18kfl%' and eventcode like 'eskb%' and pricecode like '[B,D-O]__[^P]' and CompCode=0
),

b as (
select distinct f.archticsaccountid, z.Distance
from ro.vw_FactTicketSalesBase f
left join ro.vw_DimCustomer_Base d
on f.DimCustomerId=d.DimCustomerId
left join kings.Zipcode_Distances_080217 z
on d.AddressPrimaryZip=z.ZipCode
where itemcode like '18kfl%' and eventcode like 'ESKB%' and pricecode like '[B,D-O]__[^P]' and CompCode=0
),

c as (
select distinct f.archticsaccountid, d.IsBusiness
from ro.vw_FactTicketSalesBase f
left join ro.vw_DimCustomer_Base d
on f.DimCustomerId=d.DimCustomerId
where plancode like '18kfl%' and eventcode like 'ESKB%' and pricecode like '[B,D-O]__[^P]' and CompCode=0
),

d as (
select distinct f.ArchticsAccountId,sum(blockpurchaseprice)/sum(qtyseat) as AvgSeatPrice, round(avg(cast(qtyseat as decimal(5,3))),0) as AvgQtySeat,
max(case when c.sectionname like '2__' then 1 else 0 end) as 'Upper',
max(case when m.def_price_code like '[B,K]%' then 1 else 0 end) as 'CenterSideline',
max(case when m.def_price_code like '[D,L]%' then 1 else 0 end) as 'InnerSideline',
max(case when m.def_price_code like '[E-F,M]%' then 1 else 0 end) as 'OuterSideline',
max(case when m.def_price_code like '[G,N]%' then 1 else 0 end) as 'Corner',
max(case when m.def_price_code like '[I-J,O]%' then 1 else 0 end) as 'Baseline'
from ro.vw_factticketsalesbase f
left join (select distinct archticsaccountid, sectionname, rowname, seat
from (select archticsaccountid, sectionname, rowname, seat, rank() over (partition by archticsaccountid order by eventcnt desc) as blockrank, eventcnt
		from (select archticsaccountid, sectionname, rowname, seat, count(eventcode) as eventcnt
				from ro.vw_FactTicketSalesBase
				where plancode='18kfl' and eventcode like 'ESKB%' and pricecode like '[B,D-O]__[^P]' and CompCode=0
				group by archticsaccountid, sectionname, rowname, seat
				) t
		) s
where blockrank=1) c
on f.ArchticsAccountId=c.ArchticsAccountId and f.sectionname=c.SectionName and f.rowname=c.rowname and f.seat=c.seat
inner join ro.vw_ods_TM_ManifestSeat m
on c.sectionname=m.section_name and c.rowname=m.row_name and m.manifest_id=119
where plancode like '18kfl%' and eventcode like 'ESKB%' and pricecode like '[B,D-O]__[^P]' and CompCode=0
group by f.archticsaccountid
),

e as (
select accountid, avg(cast(seatsscanned as decimal)) as AvgTixScanned, avg(cast(avgscantime as decimal)) as AvgScanTime, cast(sum(isattended) as decimal)/10.00 as PercentLast10
from (
select *, case when seatsscanned>0 then 1 else 0 end as isattended
from
(
select accountid, eventcode, eventdate, cast(sum(SeatsBought) as decimal) as SeatsBought,cast(sum(seatsscanned) as decimal) as SeatsScanned, avg(avgscantime) as AvgScanTime
from 
(select distinct accountid, eventcode, eventdate, eventtime, count(isattended) as SeatsBought, sum(isattended) as SeatsScanned, 
case when abs(datediff(mi,cast(scandatetime as time),eventtime))<=90 then avg(datediff(mi,cast(scandatetime as time),eventtime)) 
	 else null end as AvgScanTime
from ro.vw_factticketseat f
inner join (select distinct archticsaccountid
			from ro.vw_factticketsalesbase
			where itemcode like '18kfl%' and eventcode like 'eskb%' and pricecode like '[B,D-O]__[^P]' and CompCode=0
			) acct
on f.accountid=acct.ArchticsAccountId
where eventdate in (select eventdate 
					from kings.vw_retention_18eventindex
					where id<=(select id from kings.vw_retention_18eventindex where eventdate=(select max(eventdate) from kings.vw_retention_18eventindex where eventdate<=getdate()))
					and id>(select id-10 from kings.vw_retention_18eventindex where eventdate=(select max(eventdate) from kings.vw_retention_18eventindex where eventdate<=getdate()))) and istransfered is null
group by accountid, eventcode, eventdate, eventtime, scandatetime) a
group by accountid, eventcode, eventdate
) s
) p
group by accountid
),

f as (
select d.*, sum(p.resale) as Resales, sum(p.forward) as Forwards
					from (select distinct archticsaccountid
							from ro.vw_factticketsalesbase
							where itemcode like '18kfl%' and eventcode like 'eskb%' and pricecode like '[B,D-O]__[^P]' and CompCode=0
							) d
					left join (select acct_id, event_date, sum(resale) as resale, sum(forward) as forward
								from (select acct_id, event_date, num_seats,
										case when activity_name='TE Resale' then 1 else 0 end as 'Resale',
										case when activity_name='Forward' then 1 else 0 end as 'Forward'
										from ro.vw_ods_tm_tex
										where event_date in (select eventdate 
															from kings.vw_retention_18eventindex
															where id<=(select id from kings.vw_retention_18eventindex where eventdate=(select max(eventdate) from kings.vw_retention_18eventindex where eventdate<=getdate()))
															and id>(select id-10 from kings.vw_retention_18eventindex where eventdate=(select max(eventdate) from kings.vw_retention_18eventindex where eventdate<=getdate())))
										and event_name like 'ESKB%' and activity_name in ('TE Resale','Forward')
										) sub
								group by acct_id, event_Date
								) p
					on d.archticsaccountid=p.acct_id
					group by d.archticsaccountid
),

g as (
 select a.*, b.SurveysStarted12
  from (select r.*,sum(s.count) as SurveysStarted6
		from ( select distinct convert(int,archticsaccountid) as archticsaccountid
				from ro.vw_factticketsalesbase
				where itemcode like '18kfl%' and eventcode like 'eskb%' and pricecode like '[B,D-O]__[^P]' and CompCode=0
				) r
		left join (select distinct surveyname, convert(varchar,response) as 'response', started,
					case when started is not null then 1 else 0 end as 'count'
					from ro.vw_TurnkeySurveyOutput
					where response is not null and started is not null and surveyname!='2018-19 Season Ticket Member Discontinue'
					) s
		on s.started<=(getdate()) and s.started>dateadd(month,-6,getdate()) and s.response=cast(r.archticsaccountid as varchar)
		group by archticsaccountid
		) a
  inner join (select r.*,sum(s.count) as SurveysStarted12
				from ( select distinct convert(int,archticsaccountid) as archticsaccountid
						from ro.vw_factticketsalesbase
						where itemcode like '18kfl%' and eventcode like 'eskb%' and pricecode like '[B,D-O]__[^P]' and CompCode=0
						) r
				left join (select distinct surveyname, convert(varchar,response) as 'response', started,
							case when started is not null then 1 else 0 end as 'count'
							from ro.vw_TurnkeySurveyOutput
							where response is not null and started is not null and surveyname!='2018-19 Season Ticket Member Discontinue'
							) s
				on s.started<=(getdate()) and s.started>dateadd(month,-12,getdate()) and s.response=cast(r.archticsaccountid as varchar)
				group by archticsaccountid) b
  on a.archticsaccountid=b.archticsaccountid
),


emailsrec30 as (
	select c.archticsaccountid, count(distinct assetid) as EmailsRec30
				from (select distinct archticsaccountid
						from ro.vw_factticketsalesbase
						where itemcode like '18kfl%' and eventcode like 'eskb%' and pricecode like '[B,D-O]__[^P]' and CompCode=0
						)c
				left join (select distinct max(createdat) as createdat, assetid, a.contactid, b.AccountId
							from ro.vw_Eloqua_ActivityEmailSend a
							inner join (select distinct c.AccountId, s.ContactId
										from ro.vw_Eloqua_ActivityEmailSend s
										left join ro.vw_DimCustomer_Base c1 
										on s.ContactId = c1.SSID and c1.SourceSystem = 'Eloqua Kings'
										inner join ro.vw_DimCustomer_Base c 
										on c.SSB_CRMSYSTEM_CONTACT_ID = c1.SSB_CRMSYSTEM_CONTACT_ID and c.SourceSystem = 'TM' and c.IsDeleted = 0
										) b
							on a.ContactId=b.ContactId
							where createdat>=dateadd(day,-30,getdate())
							group by assetid, a.contactid, b.accountid
							) d
				on c.archticsaccountid=d.AccountId
				group by c.ArchticsAccountId
				),
			
emailsrec60 as (
select c.archticsaccountid, count(distinct assetid) as EmailsRec60
				from (select distinct archticsaccountid
						from ro.vw_factticketsalesbase
						where itemcode like '18kfl%' and eventcode like 'eskb%' and pricecode like '[B,D-O]__[^P]' and CompCode=0
						)c
				left join (select distinct max(createdat) as createdat, assetid, a.contactid, b.AccountId
							from ro.vw_Eloqua_ActivityEmailSend a
							inner join (select distinct c.AccountId, s.ContactId
										from ro.vw_Eloqua_ActivityEmailSend s
										left join ro.vw_DimCustomer_Base c1 
										on s.ContactId = c1.SSID and c1.SourceSystem = 'Eloqua Kings'
										inner join ro.vw_DimCustomer_Base c 
										on c.SSB_CRMSYSTEM_CONTACT_ID = c1.SSB_CRMSYSTEM_CONTACT_ID and c.SourceSystem = 'TM' and c.IsDeleted = 0
										) b
							on a.ContactId=b.ContactId
							where createdat>=dateadd(day,-60,getdate())
							group by assetid, a.contactid, b.accountid
							) d
				on c.archticsaccountid=d.AccountId
				group by c.ArchticsAccountId
				),

emailsopen30 as (
select c.archticsaccountid, count(distinct assetid) as EmailsOpen30
					from (select distinct archticsaccountid
							from ro.vw_factticketsalesbase
							where itemcode like '18kfl%' and eventcode like 'eskb%' and pricecode like '[B,D-O]__[^P]' and CompCode=0
							)c
					left join (select distinct min(a.createdat) as openedat, a.assetid, a.contactid, b.AccountId, e.CreatedAt as sentat
								from ro.vw_Eloqua_ActivityEmailOpen a
								inner join (select distinct c.AccountId, s.ContactId
											from ro.vw_Eloqua_ActivityEmailOpen s
											left join ro.vw_DimCustomer_Base c1 
											on s.ContactId = c1.SSID and c1.SourceSystem = 'Eloqua Kings'
											inner join ro.vw_DimCustomer_Base c 
											on c.SSB_CRMSYSTEM_CONTACT_ID = c1.SSB_CRMSYSTEM_CONTACT_ID and c.SourceSystem = 'TM' and c.IsDeleted = 0
											) b
								on a.ContactId=b.ContactId
								inner join ro.vw_eloqua_activityemailsend e
								on a.assetid=e.assetid and a.ContactId=e.ContactId
								where a.createdat>=dateadd(day,-30,getdate()) and e.CreatedAt>=dateadd(day,-30,getdate())
								group by a.assetid, a.contactid, b.accountid, e.createdat
								) d
					on c.archticsaccountid=d.AccountId
					group by c.archticsaccountid 
					),

emailsopen90 as (					
select c.archticsaccountid, count(distinct assetid) as EmailsOpen90
					from (select distinct archticsaccountid
							from ro.vw_factticketsalesbase
							where itemcode like '18kfl%' and eventcode like 'eskb%' and pricecode like '[B,D-O]__[^P]' and CompCode=0
							)c
					left join (select distinct min(a.createdat) as openedat, a.assetid, a.contactid, b.AccountId, e.CreatedAt as sentat
								from ro.vw_Eloqua_ActivityEmailOpen a
								inner join (select distinct c.AccountId, s.ContactId
											from ro.vw_Eloqua_ActivityEmailOpen s
											left join ro.vw_DimCustomer_Base c1 
											on s.ContactId = c1.SSID and c1.SourceSystem = 'Eloqua Kings'
											inner join ro.vw_DimCustomer_Base c 
											on c.SSB_CRMSYSTEM_CONTACT_ID = c1.SSB_CRMSYSTEM_CONTACT_ID and c.SourceSystem = 'TM' and c.IsDeleted = 0
											) b
								on a.ContactId=b.ContactId
								inner join ro.vw_eloqua_activityemailsend e
								on a.assetid=e.assetid and a.ContactId=e.ContactId
								where a.createdat>=dateadd(day,-90,getdate()) and e.CreatedAt>=dateadd(day,-90,getdate())
								group by a.assetid, a.contactid, b.accountid, e.createdat
								) d
					on c.archticsaccountid=d.AccountId
					group by c.archticsaccountid 
					),

emailclicks30 as (					
select c.archticsaccountid, count(distinct assetid) as EmailClicks30
					from (select distinct archticsaccountid
								from ro.vw_factticketsalesbase
								where itemcode like '18kfl%' and eventcode like 'eskb%' and pricecode like '[B,D-O]__[^P]' and CompCode=0
								)c
					left join (select distinct min(a.createdat) as clickedat, a.assetid, a.contactid, b.AccountId, e.CreatedAt as sentat
								from ro.vw_Eloqua_ActivityEmailClickThrough a
								inner join (select distinct c.AccountId, s.ContactId
											from ro.vw_Eloqua_ActivityEmailClickThrough s
											left join ro.vw_DimCustomer_Base c1 
											on s.ContactId = c1.SSID and c1.SourceSystem = 'Eloqua Kings'
											inner join ro.vw_DimCustomer_Base c 
											on c.SSB_CRMSYSTEM_CONTACT_ID = c1.SSB_CRMSYSTEM_CONTACT_ID and c.SourceSystem = 'TM' and c.IsDeleted = 0
											) b
								on a.ContactId=b.ContactId
								inner join ro.vw_eloqua_activityemailsend e
								on a.assetid=e.assetid and a.ContactId=e.ContactId
								where a.createdat>=dateadd(day,-30,getdate()) and e.CreatedAt>=dateadd(day,-30,getdate())
								group by a.assetid, a.contactid, b.accountid, e.createdat
								) d
					on c.archticsaccountid=d.AccountId
					group by c.archticsaccountid
					),
					
emailclicks60 as (
select c.archticsaccountid, count(distinct assetid) as EmailClicks60
					from (select distinct archticsaccountid
								from ro.vw_factticketsalesbase
								where itemcode like '18kfl%' and eventcode like 'eskb%' and pricecode like '[B,D-O]__[^P]' and CompCode=0
								)c
					left join (select distinct min(a.createdat) as clickedat, a.assetid, a.contactid, b.AccountId, e.CreatedAt as sentat
								from ro.vw_Eloqua_ActivityEmailClickThrough a
								inner join (select distinct c.AccountId, s.ContactId
											from ro.vw_Eloqua_ActivityEmailClickThrough s
											left join ro.vw_DimCustomer_Base c1 
											on s.ContactId = c1.SSID and c1.SourceSystem = 'Eloqua Kings'
											inner join ro.vw_DimCustomer_Base c 
											on c.SSB_CRMSYSTEM_CONTACT_ID = c1.SSB_CRMSYSTEM_CONTACT_ID and c.SourceSystem = 'TM' and c.IsDeleted = 0
											) b
								on a.ContactId=b.ContactId
								inner join ro.vw_eloqua_activityemailsend e
								on a.assetid=e.assetid and a.ContactId=e.ContactId
								where a.createdat>=dateadd(day,-60,getdate()) and e.CreatedAt>=dateadd(day,-60,getdate())
								group by a.assetid, a.contactid, b.accountid, e.createdat
								) d
					on c.archticsaccountid=d.AccountId
					group by c.archticsaccountid
					),

emailclicks90 as (
select c.archticsaccountid, count(distinct assetid) as EmailClicks90
					from (select distinct archticsaccountid
								from ro.vw_factticketsalesbase
								where itemcode like '18kfl%' and eventcode like 'eskb%' and pricecode like '[B,D-O]__[^P]' and CompCode=0
								)c
					left join (select distinct min(a.createdat) as clickedat, a.assetid, a.contactid, b.AccountId, e.CreatedAt as sentat
								from ro.vw_Eloqua_ActivityEmailClickThrough a
								inner join (select distinct c.AccountId, s.ContactId
											from ro.vw_Eloqua_ActivityEmailClickThrough s
											left join ro.vw_DimCustomer_Base c1 
											on s.ContactId = c1.SSID and c1.SourceSystem = 'Eloqua Kings'
											inner join ro.vw_DimCustomer_Base c 
											on c.SSB_CRMSYSTEM_CONTACT_ID = c1.SSB_CRMSYSTEM_CONTACT_ID and c.SourceSystem = 'TM' and c.IsDeleted = 0
											) b
								on a.ContactId=b.ContactId
								inner join ro.vw_eloqua_activityemailsend e
								on a.assetid=e.assetid and a.ContactId=e.ContactId
								where a.createdat>=dateadd(day,-90,getdate()) and e.CreatedAt>=dateadd(day,-90,getdate())
								group by a.assetid, a.contactid, b.accountid, e.createdat
								) d
					on c.archticsaccountid=d.AccountId
					group by c.archticsaccountid
					),
					
emailunsub6 as (
select c.archticsaccountid, count(distinct assetid) as EmailUnsub6
					from (select distinct archticsaccountid
									from ro.vw_factticketsalesbase
									where itemcode like '18kfl%' and eventcode like 'eskb%' and pricecode like '[B,D-O]__[^P]' and CompCode=0
									)c
					left join (select distinct min(createdat) as createdat, assetid, b.AccountId
								from ro.vw_Eloqua_ActivityEmailUnsubscribe a
								inner join (select distinct c.AccountId, s.ContactId, u.EmailAddress	
											from ro.vw_Eloqua_ActivityEmailSend s
											left join ro.vw_DimCustomer_Base c1 
											on s.ContactId = c1.SSID and c1.SourceSystem = 'Eloqua Kings'
											inner join ro.vw_DimCustomer_Base c 
											on c.SSB_CRMSYSTEM_CONTACT_ID = c1.SSB_CRMSYSTEM_CONTACT_ID and c.SourceSystem = 'TM' and c.IsDeleted = 0
											inner join ro.vw_Eloqua_ActivityEmailUnsubscribe u 
											on s.EmailAddress=u.EmailAddress
											) b
								on a.EmailAddress=b.EmailAddress
								where createdat>=dateadd(month,-6,getdate())
								group by assetid, b.accountid
								) d
					on c.archticsaccountid=d.AccountId
					group by c.archticsaccountid
					),

emailunsub12 as (
select c.archticsaccountid, count(distinct assetid) as EmailUnsub12
						from (select distinct archticsaccountid
									from ro.vw_factticketsalesbase
									where itemcode like '18kfl%' and eventcode like 'eskb%' and pricecode like '[B,D-O]__[^P]' and CompCode=0
									)c
						left join (select distinct min(createdat) as createdat, assetid, b.AccountId
									from ro.vw_Eloqua_ActivityEmailUnsubscribe a
									inner join (select distinct c.AccountId, s.ContactId, u.EmailAddress
												from ro.vw_Eloqua_ActivityEmailSend s
												left join ro.vw_DimCustomer_Base c1 
												on s.ContactId = c1.SSID and c1.SourceSystem = 'Eloqua Kings'
												inner join ro.vw_DimCustomer_Base c 
												on c.SSB_CRMSYSTEM_CONTACT_ID = c1.SSB_CRMSYSTEM_CONTACT_ID and c.SourceSystem = 'TM' and c.IsDeleted = 0
												inner join ro.vw_Eloqua_ActivityEmailUnsubscribe u 
												on s.EmailAddress=u.EmailAddress
												) b
									on a.EmailAddress=b.EmailAddress
									where createdat>=dateadd(month,-12,getdate())
									group by assetid,b.accountid
									) d
						on c.archticsaccountid=d.AccountId
						group by c.archticsaccountid
						),

emails as (
select emailsrec30.*, emailsopen30.EmailsOpen30, isnull(cast(emailsopen30.EmailsOpen30 as decimal)/nullif(cast(emailsrec30.EmailsRec30 as decimal),0),0) as OpenRate30, emailclicks30.EmailClicks30, 
isnull(cast(emailclicks30.EmailClicks30 as decimal)/nullif(cast(emailsrec30.EmailsRec30 as decimal),0),0) as ClickRate30,
isnull(cast(emailclicks30.EmailClicks30 as decimal)/nullif(cast(emailsopen30.EmailsOpen30 as decimal),0),0) as OpenClickRate30,
isnull(cast(emailclicks90.EmailClicks90 as decimal)/nullif(cast(emailsopen90.EmailsOpen90 as decimal),0),0) as OpenClickRate90,isnull(cast(emailclicks60.EmailClicks60 as decimal)/nullif(cast(emailsrec60.EmailsRec60 as decimal),0),0) as ClickRate60, 
emailunsub6.EmailUnsub6, emailunsub12.EmailUnsub12
from emailsrec30
left join emailsrec60 on emailsrec30.ArchticsAccountid=emailsrec60.ArchticsAccountId
left join emailsopen30 on emailsrec30.ArchticsAccountid=emailsopen30.ArchticsAccountId
left join emailsopen90 on emailsrec30.ArchticsAccountid=emailsopen90.ArchticsAccountId
left join emailclicks30 on emailsrec30.ArchticsAccountid=emailclicks30.ArchticsAccountId
left join emailclicks60 on emailsrec30.ArchticsAccountid=emailclicks60.ArchticsAccountId
left join emailclicks90 on emailsrec30.ArchticsAccountid=emailclicks90.ArchticsAccountId
left join emailunsub6 on emailsrec30.ArchticsAccountid=emailunsub6.ArchticsAccountId
left join emailunsub12 on emailsrec30.ArchticsAccountid=emailunsub12.ArchticsAccountId
),

i as (
select distinct archticsaccountid,
case when archticsaccountid in (select distinct archticsaccountid from ro.vw_factticketsalesbase where itemcode like '17kfl%' and eventcode like 'eskb%' and pricecode like '[B,D-O]__[^P]' and CompCode=0) then 0 else 1 end as 'Rookie'
from (select distinct archticsaccountid
		from ro.vw_factticketsalesbase
		where itemcode like '18kfl%' and eventcode like 'eskb%' and pricecode like '[B,D-O]__[^P]' and CompCode=0
		) a
),

addrev6 as (
select distinct r.archticsaccountid, sum(a.AddRev6) as AddRev6
from (select distinct archticsaccountid
		from ro.vw_factticketsalesbase
		where itemcode like '18kfl%' and eventcode like 'eskb%' and pricecode like '[B,D-O]__[^P]' and CompCode=0
		)r
left join (select distinct archticsaccountid, eventdate, sum(blockpurchaseprice) as AddRev6
					from (select archticsaccountid, EventDate, itemcode, pricecode, RetailTicketType, blockpurchaseprice, tickettypename
							from ro.vw_factticketsalesbase
							where eventdate>=dateadd(month,-6,getdate()) and eventcode like 'ESKB%'
							and (pricecode like '__H_' or pricecode like '__Q_' or pricecode like '__[G,Z,S]_' or pricecode like '__F[A-K]' or pricecode like '__U_' or retailtickettype!='')
						) b
					group by archticsaccountid, eventdate

					union all

					select distinct archticsaccountid, eventdate, sum(blockpurchaseprice) as AddRev6
					from ro.vw_factticketsalesbase
							where archticsaccountid in (select a.ArchticsAccountId
														from (select distinct archticsaccountid, min(substring(pricecode,3,1)) as Minn
																from ro.vw_FactTicketSalesBase
																where itemcode like '17kfl%' and plantypecode in ('RENEW','NEW') and len(pricecode)=4
																group by archticsaccountid
																) a
														left join (select distinct archticsaccountid, max(substring(pricecode,3,1)) as Maxx
																	from ro.vw_FactTicketSalesBase
																	where itemcode like '17kfl%' and plantypecode in ('RENEW','NEW') and len(pricecode)=4
																	group by archticsaccountid
																	) b
														on a.ArchticsAccountId=b.ArchticsAccountId
														where a.minn='K' and b.Maxx='N')
							and seasonyear=2017 and eventcode like 'ESKB%' and pricecode like '__N_' and itemcode not like '17kfl__' and eventdate>=dateadd(month,-6,getdate())
					group by archticsaccountid, eventdate

					union all

					select distinct archticsaccountid, eventdate, sum(blockpurchaseprice) as AddRev6
					from ro.vw_factticketsalesbase
							where archticsaccountid in (select a.ArchticsAccountId
														from (select distinct archticsaccountid, min(substring(pricecode,3,1)) as Minn
																from ro.vw_FactTicketSalesBase
																where itemcode like '18kfl%' and plantypecode in ('RENEW','NEW') and len(pricecode)=4
																and archticsaccountid in (select distinct accountid from kings.vw_retention_dateaccount)
																group by archticsaccountid
																) a
														left join (select distinct archticsaccountid, max(substring(pricecode,3,1)) as Maxx
																	from ro.vw_FactTicketSalesBase
																	where itemcode like '18kfl%' and plantypecode in ('RENEW','NEW') and len(pricecode)=4
																	and archticsaccountid in (select distinct accountid from kings.vw_retention_dateaccount)
																	group by archticsaccountid
																	) b
														on a.ArchticsAccountId=b.ArchticsAccountId
														where a.minn='K' and b.Maxx='N')
							and seasonyear=2018 and eventcode like 'ESKB%' and pricecode like '__N_' and itemcode not like '18kfl__' and eventdate>=dateadd(month,-6,getdate())
					group by archticsaccountid, eventdate
					) a
on r.archticsaccountid=a.archticsaccountid
group by r.archticsaccountid
),

addrev12 as (
select distinct r.archticsaccountid, sum(a.AddRev12) as AddRev12
from (select distinct archticsaccountid
		from ro.vw_factticketsalesbase
		where itemcode like '18kfl%' and eventcode like 'eskb%' and pricecode like '[B,D-O]__[^P]' and CompCode=0
		)r
left join (select distinct archticsaccountid, eventdate, sum(blockpurchaseprice) as AddRev12
					from (select archticsaccountid, EventDate, itemcode, pricecode, RetailTicketType, blockpurchaseprice, tickettypename
							from ro.vw_factticketsalesbase
							where eventdate>=dateadd(month,-12,getdate()) and eventdate<=getdate() and eventcode like 'ESKB%'
							and (pricecode like '__H_' or pricecode like '__Q_' or pricecode like '__[G,Z,S]_' or pricecode like '__F[A-K]' or pricecode like '__U_' or retailtickettype!='')
						) b
					group by archticsaccountid, eventdate

					union all

					select distinct archticsaccountid, eventdate, sum(blockpurchaseprice) as AddRev12
					from ro.vw_factticketsalesbase
							where archticsaccountid in (select a.ArchticsAccountId
														from (select distinct archticsaccountid, min(substring(pricecode,3,1)) as Minn
																from ro.vw_FactTicketSalesBase
																where itemcode like '17kfl%' and plantypecode in ('RENEW','NEW') and len(pricecode)=4
																group by archticsaccountid
																) a
														left join (select distinct archticsaccountid, max(substring(pricecode,3,1)) as Maxx
																	from ro.vw_FactTicketSalesBase
																	where itemcode like '17kfl%' and plantypecode in ('RENEW','NEW') and len(pricecode)=4
																	group by archticsaccountid
																	) b
														on a.ArchticsAccountId=b.ArchticsAccountId
														where a.minn='K' and b.Maxx='N')
							and seasonyear=2017 and eventcode like 'ESKB%' and pricecode like '__N_' and itemcode not like '17kfl__' and eventdate>=dateadd(month,-12,getdate()) and eventdate<=getdate()
					group by archticsaccountid, eventdate

					union all

					select distinct archticsaccountid, eventdate, sum(blockpurchaseprice) as AddRev12
					from ro.vw_factticketsalesbase
							where archticsaccountid in (select a.ArchticsAccountId
														from (select distinct archticsaccountid, min(substring(pricecode,3,1)) as Minn
																from ro.vw_FactTicketSalesBase
																where itemcode like '18kfl%' and plantypecode in ('RENEW','NEW') and len(pricecode)=4
																and archticsaccountid in (select distinct accountid from kings.vw_retention_dateaccount)
																group by archticsaccountid
																) a
														left join (select distinct archticsaccountid, max(substring(pricecode,3,1)) as Maxx
																	from ro.vw_FactTicketSalesBase
																	where itemcode like '18kfl%' and plantypecode in ('RENEW','NEW') and len(pricecode)=4
																	and archticsaccountid in (select distinct accountid from kings.vw_retention_dateaccount)
																	group by archticsaccountid
																	) b
														on a.ArchticsAccountId=b.ArchticsAccountId
														where a.minn='K' and b.Maxx='N')
							and seasonyear=2018 and eventcode like 'ESKB%' and pricecode like '__N_' and itemcode not like '18kfl__' and eventdate>=dateadd(month,-12,getdate()) and eventdate<=getdate()
					group by archticsaccountid, eventdate
					) a
on r.archticsaccountid=a.archticsaccountid
group by r.archticsaccountid
),

arenarev12 as (
select r.archticsaccountid, isnull(sum(a.revenue),0) as ArenaRev12
from (select distinct archticsaccountid
				from ro.vw_factticketsalesbase
				where itemcode like '18kfl%' and eventcode like 'eskb%' and pricecode like '[B,D-O]__[^P]' and CompCode=0
				) r
		left join (select a.ArchticsAccountId,eventdate,sum(transaction_amount) as revenue
					from (select distinct f.ArchticsAccountId, t.calc_hostaccountid
							from ro.vw_host_trans_todate t
							left join ro.vw_DimCustomer_Base d
							on t.calc_hostaccountid=d.SSID and d.SourceSystem='Host Kings'
							left join ro.vw_dimcustomer_base d1
							on d.SSB_CRMSYSTEM_CONTACT_ID=d1.SSB_CRMSYSTEM_CONTACT_ID and d1.SourceSystem='TM'
							left join ro.vw_factticketsalesbase f
							on d1.accountid=f.ArchticsAccountId
							inner join kings.vw_retention_dateaccount r
							on r.accountid=f.ArchticsAccountId
							where f.eventdate>=dateadd(month,-12,getdate()))a
					left join ro.vw_Host_Trans_ToDate t
					on t.calc_hostaccountid=a.Calc_HostAccountId
					where eventdate>=dateadd(month,-12,getdate()) and eventdate<=getdate() and primaryact!='Sacramento Kings'
					group by archticsaccountid, eventdate
					) a
		on r.archticsaccountid=a.archticsaccountid
		group by r.archticsaccountid
),

l as (
select distinct archticsaccountid, sum(GroupLeader) as GroupLeader from (
select distinct archticsaccountid, case when pricecode like '__[G,Z,S]_' then 1 else 0 end as GroupLeader
from ro.vw_factticketsalesbase
where archticsaccountid in (select distinct archticsaccountid from ro.vw_factticketsalesbase where itemcode like '18kfl%' and pricecode like '[B,D-O]__[^P]' and eventcode like 'ESKB%' and CompCode=0)
and seasonyear=2018 ) a group by archticsaccountid
),

m as (
select r.archticsaccountid, (2018-stmsince) as Tenure
from (select distinct archticsaccountid
		from ro.vw_factticketsalesbase
		where itemcode like '18kfl%' and eventcode like 'eskb%' and pricecode like '[B,D-O]__[^P]' and CompCode=0) r
left join (select *
			from kings.vw_retention_tenureyear1
			union all
			select *
			from kings.vw_retention_tenureyear2
			union all
			select *
			from kings.vw_retention_tenureyear3
			union all
			select *
			from kings.vw_retention_tenureyear4
			union all
			select archticsaccountid as accountid, tenure as stmsince
			from kings.vw_retention_tenureyear5
			) a
on r.archticsaccountid=a.accountid
),

n as (
select a.accountid, sum(a.count) as Declines3
from (select *, case when accountid is not null then 1 else 1 end as Count
				from kings.stm_declines
				) a
		inner join (select distinct archticsaccountid
						from ro.vw_factticketsalesbase
						where itemcode like '18kfl%' and eventcode like 'eskb%' and pricecode like '[B,D-O]__[^P]' and CompCode=0
						) d
		on a.date<=getdate() and a.date>dateadd(month,-3,getdate()) and a.accountid=d.ArchticsAccountId
		group by a.accountid
)

select distinct a.archticsAccountId,b.Distance, c.IsBusiness, d.AvgQtySeat, d.AvgSeatPrice, d.Upper, d.CenterSideline,
d.InnerSideline,d.OuterSideline,d.Corner,d.Baseline, e.AvgScanTime,isnull(e.AvgTixScanned,0) as AvgTixScanned,isnull(e.PercentLast10,0) as PercentLast10,
isnull(f.Resales,0) as Resales,isnull(f.Forwards,0) as Forwards, isnull(g.SurveysStarted6,0) as SurveysStarted6,isnull(g.SurveysStarted12,0) as SurveysStarted12,
emails.EmailsRec30, emails.EmailsOpen30, emails.OpenRate30, emails.EmailClicks30, emails.ClickRate30,emails.OpenClickRate30,emails.ClickRate60,emails.OpenClickRate90, emails.EmailUnsub6, emails.EmailUnsub12,
i.Rookie,isnull(addrev6.AddRev6,0) as AddRev6, isnull(addrev12.AddRev12,0) as AddRev12, arenarev12.ArenaRev12,l.GroupLeader, isnull(m.Tenure,0) as Tenure, isnull(n.Declines3,0) as Declines3,
case when datepart(month,getdate())=1 then 1 else 0 end as 'January',
case when datepart(month,getdate())=2 then 1 else 0 end as 'February',
case when datepart(month,getdate())=3 then 1 else 0 end as 'March',
case when datepart(month,getdate())=4 then 1 else 0 end as 'April',
case when datepart(month,getdate())=5 then 1 else 0 end as 'May',
case when datepart(month,getdate())=6 then 1 else 0 end as 'June',
case when datepart(month,getdate())=7 then 1 else 0 end as 'July',
case when datepart(month,getdate())=8 then 1 else 0 end as 'August',
case when datepart(month,getdate())=9 then 1 else 0 end as 'September',
case when datepart(month,getdate())=10 then 1 else 0 end as 'October',
case when datepart(month,getdate())=11 then 1 else 0 end as 'November',
case when datepart(month,getdate())=12 then 1 else 0 end as 'December'
from a
left join b on a.archticsaccountid=b.archticsaccountid
left join c on a.archticsaccountid=c.archticsaccountid
left join d on a.archticsaccountid=d.ArchticsAccountId
left join e on a.archticsaccountid=e.accountid
left join f on a.archticsaccountid=f.archticsaccountid
left join g on a.archticsaccountid=g.archticsaccountid
left join emails on a.archticsaccountid=emails.archticsaccountid
left join i on a.archticsaccountid=i.archticsaccountid
left join addrev6 on a.archticsaccountid=addrev6.archticsaccountid
left join addrev12 on a.archticsaccountid=addrev12.ArchticsAccountId
left join arenarev12 on a.archticsaccountid=arenarev12.archticsaccountid
left join l on a.archticsaccountid=l.archticsaccountid
left join m on a.archticsaccountid=m.archticsaccountid
left join n on a.archticsaccountid=n.accountid
GO

