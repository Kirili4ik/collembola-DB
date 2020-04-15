create sequence authors_id_seq;

alter sequence authors_id_seq owner to postgres;

create table laboratories
(
	lab_name text,
	foundation_year integer default 0,
	lab_size integer,
	lab_id serial not null
		constraint laboratories_pk
			primary key
);

alter table laboratories owner to postgres;

create table users
(
	surname text,
	name_usr text,
	sec_name text,
	full_name text,
	lab_id integer
		constraint users_laboratories_lab_id_fk
			references laboratories
				on update cascade on delete cascade,
	user_id serial not null
		constraint users_pk
			primary key
);

alter table users owner to postgres;

create table habitats
(
	habitat_name text,
	habitat_name_ru text,
	habitat_id serial not null
		constraint habitats_pk
			primary key
);

alter table habitats owner to postgres;

create table microhabitats
(
	microhabitat_name text,
	microhabitat_name_ru text,
	microhabitat_id serial not null
		constraint microhabitats_pk
			primary key
);

alter table microhabitats owner to postgres;

create table authors
(
	author text,
	year_found integer,
	brackets text,
	author_id serial not null
		constraint authors_pk
			primary key
);

alter table authors owner to postgres;

create table taxons
(
	taxon text,
	synonyms text,
	synonyms_exist boolean default false,
	author_id integer
		constraint taxons_authors_author_id_fk
			references authors
				on update cascade on delete cascade,
	taxon_rank text,
	taxon_parent integer not null,
	taxon_id serial not null
		constraint taxons_pk
			primary key
);

alter table taxons owner to postgres;

create table events
(
	event_name text,
	habitat_id integer
		constraint events_habitats_habitat_id_fk
			references habitats
				on update cascade on delete cascade,
	microhabitat_id integer
		constraint events_microhabitats_microhabitat_id_fk
			references microhabitats
				on update cascade on delete cascade,
	latitude numeric,
	longitude numeric,
	event_date date,
	event_id serial not null
		constraint events_pk
			primary key
);

alter table events owner to postgres;

create table populations
(
	taxon_id integer
		constraint populations_taxons_taxon_id_fk
			references taxons
				on update cascade on delete cascade,
	population integer,
	found_id integer
		constraint populations_users_user_id_fk
			references users
				on update cascade on delete cascade,
	identified_id integer
		constraint populations_users_user_id_fk_2
			references users
				on update cascade on delete cascade,
	event_id integer
		constraint populations_events_event_id_fk
			references events
				on update cascade on delete cascade,
	population_id serial not null
		constraint populations_pk
			primary key
);

alter table populations owner to postgres;

create materialized view hab_ev as
SELECT e.event_name,
    h.habitat_name_ru,
    t.taxon,
    p.population
   FROM habitats h
     JOIN events e ON h.habitat_id = e.habitat_id
     JOIN populations p ON e.event_id = p.event_id
     JOIN taxons t ON p.taxon_id = t.taxon_id
  GROUP BY e.event_name, h.habitat_id, t.taxon, p.population
  ORDER BY e.event_name, p.population DESC;

alter materialized view hab_ev owner to postgres;

create materialized view full_taxonomy as
SELECT t1.taxon AS class,
    t2.taxon AS order_,
    t3.taxon AS family,
    t4.taxon AS genus,
    t5.taxon AS species
   FROM taxons t1
     LEFT JOIN taxons t2 ON t1.taxon_id = t2.taxon_parent
     LEFT JOIN taxons t3 ON t2.taxon_id = t3.taxon_parent
     LEFT JOIN taxons t4 ON t3.taxon_id = t4.taxon_parent
     LEFT JOIN taxons t5 ON t4.taxon_id = t5.taxon_parent
  WHERE t1.taxon_rank = 'class'::text;

alter materialized view full_taxonomy owner to postgres;

create function add_event_date() returns trigger
	language plpgsql
as $$
  BEGIN
    IF (old.event_date is NULL) THEN
        UPDATE events
        SET event_date = current_date
        WHERE event_id = new.event_id;
    END IF;
    RETURN NULL;
  END;
$$;

alter function add_event_date() owner to postgres;

create trigger add_event_check
	after insert
	on events
	for each row
	execute procedure add_event_date();

create function make_user_pro() returns trigger
	language plpgsql
as $$
  BEGIN
    UPDATE users
    SET full_name = (NEW.surname || ' ' || NEW.name_usr || ' ' || NEW.sec_name)
    WHERE user_id = NEW.user_id;
    --WHERE surname = NEW.surname AND name_usr = NEW.name_usr AND sec_name = NEW.sec_name;
    RETURN NULL;
  END;
$$;

alter function make_user_pro() owner to postgres;

create trigger make_user
	after insert
	on users
	for each row
	execute procedure make_user_pro();

create function count_by_letters() returns TABLE(letter character, num bigint)
	language sql
as $$
 SELECT substr( taxon, 1, 1 ) AS letter, count( * )
 FROM taxons GROUP BY letter ORDER BY letter;
$$;

alter function count_by_letters() owner to postgres;

create function person_func() returns trigger
	language plpgsql
as $$
    BEGIN
    IF POSITION(' ' IN NEW.name_usr) > 0 OR
    POSITION(' ' IN NEW.surname) > 0 OR POSITION(' ' IN NEW.sec_name) > 0
    THEN
        RAISE EXCEPTION 'Name, surname and second name must not include white space.';
    END IF;
    RETURN NEW;
    END
$$;

alter function person_func() owner to postgres;

create trigger person_trigger
	before insert
	on users
	for each row
	execute procedure person_func();

create function translate_habitat(rus_name text, OUT eng_name text) returns text
	language sql
as $$
    SELECT habitat_name FROM habitats
      WHERE habitat_name_ru = rus_name;
$$;

alter function translate_habitat(text, out text) owner to postgres;


