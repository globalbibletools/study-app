--------------------------------------------------------------
--RS SESSION READ TIME--
--------------------------------------------------------------
--Sessions previously derived their duration from the start/end wall-clock
--timestamps. That includes time the app spent backgrounded, so it cannot be
--used once the in-app timer pauses. Store the accumulated foreground read
--time separately and backfill it from the old wall-clock interval for
--existing sessions.

alter table rs_session
    add column read_seconds int not null default 0;

update rs_session
   set read_seconds = max(
           0,
           cast(strftime('%s', end_time) as integer) -
           cast(strftime('%s', start_time) as integer)
       )
 where end_time is not null;
