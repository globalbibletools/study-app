-----------------------------
--READING SESSION DAILY LOG--
-----------------------------
--tracks the time spent in each daily reading session

create table rs_daily_log (
    id integer primary key autoincrement,
    rs_date date not null,
    start_time timestamp not null,
    end_time timestamp,
    verses int not null
);

-----------------------
--READING SESSION LOG--
-----------------------
--tracks the reading timestamp for each verse

create table rs_log (
    id integer primary key autoincrement,
    rs_daily_log_id integer not null,
    book_id integer not null,
    chapter integer not null,
    verse integer not null,
    date_time timestamp not null
);

------------------------------
--READING SESSION STATISTICS--
------------------------------
--reading session statistics to track daily/monthly reading
--type : D for daily, M for monthly
--stats_date : local date for daily stats, end of month date for monthly stats
create table rs_stats (
    id integer primary key autoincrement,
    type varchar(1) not null,
    stats_date date not null,
    rs_seconds int not null,
    rs_verses int not null,
    goal_reached int not null
);

CREATE UNIQUE INDEX hash_type_date
ON rs_stats(type, stats_date);


---------------------------------
--READING SESSION BOOK PROGRESS--
---------------------------------
--track each book progress by chapter and verse
create table rs_book_progress (
    id integer primary key autoincrement,
    book_id int not null,
    chapter int not null,
    verse int not null,
    chapters_read int not null,
    updated_at datetime not null
);

CREATE UNIQUE INDEX hash_rs_book_progress
ON rs_book_progress(book_id);