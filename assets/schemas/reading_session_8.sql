--------------------------------------------------------------
--DROP READING PLAN COLLECTION ID--
--------------------------------------------------------------
--The ordered reading_plan_book list is the source of truth for which books
--a plan covers; collection_id was denormalized persistence of that list and
--could drift from it. Drop the column via a table rebuild (create-copy-drop)
--rather than ALTER TABLE DROP COLUMN: sqflite on Android runs the OS-bundled
--SQLite, and DROP COLUMN needs SQLite >= 3.35 while this app supports older
--devices. Rows, ids, defaults, and foreign keys are preserved.

PRAGMA foreign_keys = OFF;

create table reading_plan_new (
    id integer primary key autoincrement,
    plan_name text not null,
    created_at timestamp not null,
    last_read timestamp,
    goal_type varchar(1),
    goal_value int not null,
    is_bookmarked int not null
);

insert into reading_plan_new
    (id, plan_name, created_at, last_read, goal_type, goal_value, is_bookmarked)
select id, plan_name, created_at, last_read, goal_type, goal_value, is_bookmarked
from reading_plan;

drop table reading_plan;

alter table reading_plan_new rename to reading_plan;

PRAGMA foreign_keys = ON;
