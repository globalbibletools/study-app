create table rs_verse_state (
    reading_plan_id int not null,
    book_id int not null,
    chapter int not null,
    verse int not null,
    read_count int not null default 0,
    last_read text,
    foreign key (reading_plan_id) references reading_plan(id),
    primary key (reading_plan_id, book_id, chapter, verse)
);

create index idx_rs_verse_state_plan_book
on rs_verse_state(reading_plan_id, book_id);

insert into rs_verse_state
    (reading_plan_id, book_id, chapter, verse, read_count, last_read)
select reading_plan_id, book_id, chapter, verse, count(*), max(date_time)
from rs_log
group by reading_plan_id, book_id, chapter, verse;

drop index hash_rs_book_progress;
drop table rs_book_progress;
