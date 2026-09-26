-----------------------------
--READING PLAN--
-----------------------------
--for tracking reading for different bible collections

create table reading_plan (
    id integer primary key autoincrement,
    plan_name text not null,
    created_at timestamp not null,
    last_read timestamp,
    collection_id int not null,
    goal_type varchar(1) not null,
    goal_value int not null,
    is_bookmarked int not null
);

-----------------------------
--READING PLAN BOOK--
-----------------------------
--table to link different books to a reading plan

create table reading_plan_book (
    id integer primary key autoincrement,
    reading_plan_id int not null,
    book_id int not null,
    ord int not null,
    foreign key (reading_plan_id) references reading_plan(id)
);

PRAGMA foreign_keys = OFF;

ALTER TABLE rs_daily_log RENAME TO rs_daily_log_old;

create table rs_daily_log (
    id integer primary key autoincrement,
    rs_date date not null,
    start_time timestamp not null,
    end_time timestamp,
    verses int not null,
    reading_plan_id int not null,
    foreign key (reading_plan_id) references reading_plan(id)
);

INSERT INTO rs_daily_log
SELECT rs_daily_log_old.*, 1
FROM rs_daily_log_old;

DROP TABLE rs_daily_log_old;


ALTER TABLE rs_log RENAME TO rs_log_old;

create table rs_log (
    id integer primary key autoincrement,
    rs_daily_log_id integer not null,
    book_id integer not null,
    chapter integer not null,
    verse integer not null,
    date_time timestamp not null,
    reading_plan_id int not null,
    foreign key (rs_daily_log_id) references rs_daily_log(id),
    foreign key (reading_plan_id) references reading_plan(id)
);

INSERT INTO rs_log
SELECT rs_log_old.*, 1
FROM rs_log_old;

DROP TABLE rs_log_old;

ALTER TABLE rs_book_progress RENAME TO rs_book_progress_old;

drop index hash_rs_book_progress;

create table rs_book_progress (
    id integer primary key autoincrement,
    book_id int not null,
    chapter int not null,
    verse int not null,
    chapters_read int not null,
    verses_read int not null,
    updated_at datetime not null,
    reading_plan_id int not null,
    foreign key (reading_plan_id) references reading_plan(id)
);

CREATE UNIQUE INDEX hash_rs_book_progress
ON rs_book_progress(book_id, reading_plan_id);

INSERT INTO rs_book_progress
SELECT rs_book_progress_old.*, 1
FROM rs_book_progress_old;

drop table rs_book_progress_old;



ALTER TABLE rs_stats RENAME TO rs_stats_old;

drop index hash_type_date;

create table rs_stats (
    id integer primary key autoincrement,
    type varchar(1) not null,
    stats_date date not null,
    rs_seconds int not null,
    rs_verses int not null,
    goal_reached int not null,
    reading_plan_id int not null,
    foreign key (reading_plan_id) references reading_plan(id)
);

CREATE UNIQUE INDEX hash_type_date
ON rs_stats(type, stats_date, reading_plan_id);

INSERT INTO rs_stats
SELECT rs_stats_old.*, 1
FROM rs_stats_old;

drop table rs_stats_old;

PRAGMA foreign_keys = ON;

insert into reading_plan (id, plan_name, created_at, last_read, collection_id, goal_type, goal_value, is_bookmarked)
values (1, 'Whole Bible', CURRENT_TIMESTAMP, null, 1, 'M', 10, 0);

insert into reading_plan_book (reading_plan_id, book_id, ord)
values
(1, 1, 1),
(1, 2, 2),
(1, 3, 3),
(1, 4, 4),
(1, 5, 5),
(1, 6, 6),
(1, 7, 7),
(1, 8, 8),
(1, 9, 9),
(1, 10, 10),
(1, 11, 11),
(1, 12, 12),
(1, 13, 13),
(1, 14, 14),
(1, 15, 15),
(1, 16, 16),
(1, 17, 17),
(1, 18, 18),
(1, 19, 19),
(1, 20, 20),
(1, 21, 21),
(1, 22, 22),
(1, 23, 23),
(1, 24, 24),
(1, 25, 25),
(1, 26, 26),
(1, 27, 27),
(1, 28, 28),
(1, 29, 29),
(1, 30, 30),
(1, 31, 31),
(1, 32, 32),
(1, 33, 33),
(1, 34, 34),
(1, 35, 35),
(1, 36, 36),
(1, 37, 37),
(1, 38, 38),
(1, 39, 39),
(1, 40, 40),
(1, 41, 41),
(1, 42, 42),
(1, 43, 43),
(1, 44, 44),
(1, 45, 45),
(1, 46, 46),
(1, 47, 47),
(1, 48, 48),
(1, 49, 49),
(1, 50, 50),
(1, 51, 51),
(1, 52, 52),
(1, 53, 53),
(1, 54, 54),
(1, 55, 55),
(1, 56, 56),
(1, 57, 57),
(1, 58, 58),
(1, 59, 59),
(1, 60, 60),
(1, 61, 61),
(1, 62, 62),
(1, 63, 63),
(1, 64, 64),
(1, 65, 65),
(1, 66, 66);
