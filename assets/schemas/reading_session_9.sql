--------------------------------------------------------------
--UNIFY THE READING PLAN MODEL--
--------------------------------------------------------------
--The reading plan is now a single model: the reading_plan columns plus an
--ordered list of book ids. reading_plan.last_read was never written by the
--app (the read position is derived from rs_log), so drop it. reading_plan_book
--no longer needs a surrogate id: (reading_plan_id, book_id) identifies a row
--and ord preserves reading order. Rebuild both tables with the
--create-copy-drop pattern rather than ALTER TABLE DROP COLUMN: sqflite on
--Android runs the OS-bundled SQLite, and DROP COLUMN needs SQLite >= 3.35
--while this app supports older devices. Rows, ids, defaults, and foreign keys
--are preserved.

PRAGMA foreign_keys = OFF;

create table reading_plan_new (
    id integer primary key autoincrement,
    plan_name text not null,
    created_at timestamp not null,
    goal_type varchar(1),
    goal_value int not null,
    is_bookmarked int not null
);

insert into reading_plan_new
    (id, plan_name, created_at, goal_type, goal_value, is_bookmarked)
select id, plan_name, created_at, goal_type, goal_value, is_bookmarked
from reading_plan;

drop table reading_plan;

alter table reading_plan_new rename to reading_plan;

create table reading_plan_book_new (
    reading_plan_id int not null,
    book_id int not null,
    ord int not null,
    foreign key (reading_plan_id) references reading_plan(id),
    primary key (reading_plan_id, book_id)
);

insert into reading_plan_book_new (reading_plan_id, book_id, ord)
select reading_plan_id, book_id, ord
from reading_plan_book;

drop table reading_plan_book;

alter table reading_plan_book_new rename to reading_plan_book;

PRAGMA foreign_keys = ON;
