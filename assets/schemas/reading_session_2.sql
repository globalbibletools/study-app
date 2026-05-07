alter table rs_book_progress add verses_read int default 0 not null;

update rs_book_progress set verses_read = (SELECT COUNT(distinct verse) AS count FROM rs_log where rs_log.book_id = rs_book_progress.book_id);
