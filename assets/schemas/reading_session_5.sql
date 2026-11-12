--------------------------------------------------------------
--RS SESSION + RS DAY SUMMARY (consolidated schema upgrade)--
--------------------------------------------------------------
--One atomic upgrade from the pre-refactor schema (v4) to the
--rs_session/rs_day_summary model. It performs four operations:
--
--1. Kill-resilient session finalization: killed sessions (end_time null,
--   verses > 0) get their end_time from the last rs_log row for that
--   session. Empty sessions are preserved: they still record when the user
--   opened the plan. Sessions now carry an end_time heartbeat in the running
--   app, so the end_time IS NOT NULL filter the old totals used is gone for
--   good.
--2. rs_daily_log is renamed to rs_session via a table rebuild
--   (create-copy-drop), not ALTER TABLE RENAME COLUMN, because sqflite on
--   Android runs the OS-bundled SQLite and RENAME COLUMN needs
--   SQLite >= 3.25 (Android API 29+) while this app supports older
--   devices. rs_daily_log was misnamed anyway: one row per session, not
--   per day. rs_log.rs_daily_log_id becomes rs_log.rs_session_id.
--3. rs_day_summary is created and backfilled: totals are recomputed from
--   the (finalized) sessions, goal-reached flags come from the historical
--   daily rs_stats rows, days without a stats row are evaluated
--   best-effort against the current plan goal, and the goal snapshot is
--   the current plan goal (the true historical goal is not recoverable).
--4. rs_stats is retired (dropped with its hash_type_date index): monthly
--   ('M') rows were never read, and daily aggregates now live in
--   rs_day_summary, written on every session/log write.

PRAGMA foreign_keys = OFF;

--1. Finalize killed sessions. Empty sessions are kept as-is.
update rs_daily_log
   set end_time = (select max(date_time) from rs_log
                    where rs_log.rs_daily_log_id = rs_daily_log.id)
 where end_time is null and verses > 0;

--2. Rename rs_daily_log to rs_session.
create table rs_session (
    id integer primary key autoincrement,
    rs_date date not null,
    start_time timestamp not null,
    end_time timestamp,
    verses int not null,
    reading_plan_id int not null,
    foreign key (reading_plan_id) references reading_plan(id)
);

insert into rs_session (id, rs_date, start_time, end_time, verses, reading_plan_id)
select id, rs_date, start_time, end_time, verses, reading_plan_id
from rs_daily_log;

create table rs_log_new (
    id integer primary key autoincrement,
    rs_session_id integer not null,
    book_id integer not null,
    chapter integer not null,
    verse integer not null,
    date_time timestamp not null,
    reading_plan_id int not null,
    foreign key (rs_session_id) references rs_session(id),
    foreign key (reading_plan_id) references reading_plan(id)
);

insert into rs_log_new (id, rs_session_id, book_id, chapter, verse, date_time, reading_plan_id)
select id, rs_daily_log_id, book_id, chapter, verse, date_time, reading_plan_id
from rs_log;

drop table rs_log;

alter table rs_log_new rename to rs_log;

drop table rs_daily_log;

--3. Create and backfill rs_day_summary (no end_time filter: orphans are
--   finalized above, so historical killed sessions count from now on).
create table rs_day_summary (
    reading_plan_id int not null,
    rs_date date not null,
    rs_seconds int not null,
    rs_verses int not null,
    goal_type varchar(1),
    goal_value int,
    goal_reached int not null default 0,
    foreign key (reading_plan_id) references reading_plan(id),
    primary key (reading_plan_id, rs_date)
);

insert into rs_day_summary
    (reading_plan_id, rs_date, rs_seconds, rs_verses,
     goal_type, goal_value, goal_reached)
select s.reading_plan_id, date(s.rs_date),
       coalesce(sum(strftime('%s', s.end_time) - strftime('%s', s.start_time)), 0),
       coalesce(sum(s.verses), 0),
       p.goal_type, p.goal_value,
       coalesce(max(st.goal_reached),
         case when (lower(p.goal_type) like 'm%' and
                    coalesce(sum(strftime('%s', s.end_time) - strftime('%s', s.start_time)), 0)
                      >= p.goal_value * 60)
                    or (lower(p.goal_type) not like 'm%' and
                        coalesce(sum(s.verses), 0) >= p.goal_value)
                  then 1 else 0 end)
from rs_session s
join reading_plan p on p.id = s.reading_plan_id
left join rs_stats st
  on st.type = 'D' and date(st.stats_date) = date(s.rs_date)
 and st.reading_plan_id = s.reading_plan_id
group by s.reading_plan_id, date(s.rs_date);

--4. Retire rs_stats.
drop index hash_type_date;

drop table rs_stats;

PRAGMA foreign_keys = ON;
