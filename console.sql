--authors
ALTER TABLE authors ADD COLUMN ids serial;
UPDATE authors set ids = author_id;
ALTER TABLE authors DROP CONSTRAINT authors_pk;
ALTER TABLE authors ADD CONSTRAINT  authors_pk
  PRIMARY KEY (ids);
ALTER TABLE authors DROP COLUMN author_id;
ALTER TABLE authors RENAME COLUMN ids TO author_id;

--events
ALTER TABLE events ADD COLUMN ids serial;
UPDATE events set ids = event_id;
ALTER TABLE events DROP CONSTRAINT events_ready_pk;
ALTER TABLE events ADD CONSTRAINT events_pk
  PRIMARY KEY (ids);
ALTER TABLE events DROP COLUMN event_id;
ALTER TABLE events RENAME COLUMN ids TO event_id;

--habitats
ALTER TABLE habitats ADD COLUMN ids serial;
UPDATE habitats set ids = habitat_id;
ALTER TABLE habitats DROP CONSTRAINT habits_ready_pk;
ALTER TABLE habitats ADD CONSTRAINT habitats_pk
  PRIMARY KEY (ids);
ALTER TABLE habitats DROP COLUMN habitat_id;
ALTER TABLE habitats RENAME COLUMN ids TO habitat_id;

--laboratories
ALTER TABLE laboratories ADD COLUMN ids serial;
UPDATE laboratories set ids = lab_id;
ALTER TABLE laboratories DROP CONSTRAINT laboratories_pk;
ALTER TABLE laboratories ADD CONSTRAINT laboratories_pk
  PRIMARY KEY (ids);
ALTER TABLE laboratories DROP COLUMN lab_id;
ALTER TABLE laboratories RENAME COLUMN ids TO lab_id;

--microhabitats
ALTER TABLE microhabitats ADD COLUMN ids serial;
UPDATE microhabitats set ids = microhabitat_id;
ALTER TABLE microhabitats DROP CONSTRAINT microhabitats_pk;
ALTER TABLE microhabitats ADD CONSTRAINT microhabitats_pk
  PRIMARY KEY (ids);
ALTER TABLE microhabitats DROP COLUMN microhabitat_id;
ALTER TABLE microhabitats RENAME COLUMN ids TO microhabitat_id;

--populations
ALTER TABLE populations ADD COLUMN ids serial;
UPDATE populations set ids = population_id;
ALTER TABLE populations DROP CONSTRAINT populations_pk;
ALTER TABLE populations ADD CONSTRAINT populations_pk
  PRIMARY KEY (ids);
ALTER TABLE populations DROP COLUMN population_id;
ALTER TABLE populations RENAME COLUMN ids TO population_id;

--taxons
ALTER TABLE taxons ADD COLUMN ids serial;
UPDATE taxons set ids = taxon_id;
ALTER TABLE taxons DROP CONSTRAINT taxons_pk;
ALTER TABLE taxons ADD CONSTRAINT taxons_pk
  PRIMARY KEY (ids);
ALTER TABLE taxons DROP COLUMN taxon_id;
ALTER TABLE taxons RENAME COLUMN ids TO taxon_id;

--users
ALTER TABLE users ADD COLUMN ids serial;
UPDATE users set ids = user_id;
ALTER TABLE users DROP CONSTRAINT users_ready_pk;
ALTER TABLE users ADD CONSTRAINT users_pk
  PRIMARY KEY (ids);
ALTER TABLE users DROP COLUMN user_id;
ALTER TABLE users RENAME COLUMN ids TO user_id;


SELECT u.full_name, coalesce(sum(p.population), 0) as found
  FROM users AS u
  LEFT OUTER JOIN populations p on u.user_id = p.found_id
  GROUP BY u.full_name
  ORDER BY found DESC;

SELECT u.full_name, coalesce(sum(p.population), 0) as identified
  FROM users AS u
  LEFT OUTER JOIN populations p on u.user_id = p.identified_id
  GROUP BY u.full_name
  ORDER BY u.full_name;

-- CTE
WITH hab_pop AS (
  SELECT e.event_name, h.habitat_name_ru, t.taxon, p.population
    FROM habitats AS h
    JOIN events e on h.habitat_id = e.habitat_id
    JOIN populations p on e.event_id = p.event_id
    JOIN taxons t on p.taxon_id = t.taxon_id
) SELECT taxon, habitat_name_ru, event_name, sum(population)
    FROM hab_pop
    WHERE taxon = 'notabilis'
    GROUP BY taxon, habitat_name_ru, event_name
    ORDER BY sum(population) DESC;

-- подзапрос
SELECT taxon_parent, taxon
  FROM taxons
  WHERE taxon_id IN (
    SELECT p.taxon_id
      FROM populations as p, users as u
      WHERE u.name_usr = 'Ксения'
      AND p.identified_id = u.user_id
  ) AND author_id IN (
    SELECT a.author_id
      FROM authors as a
      WHERE a.year_found > 1900
  ) AND taxon_rank = 'genus';

-- materialized view
CREATE MATERIALIZED VIEW hab_ev AS (
  SELECT e.event_name, h.habitat_name_ru, t.taxon, p.population  FROM habitats h
  JOIN events e on h.habitat_id = e.habitat_id
  JOIN populations p on e.event_id = p.event_id
  JOIN taxons t on p.taxon_id = t.taxon_id
  GROUP BY e.event_name, h.habitat_id, t.taxon, p.population
  ORDER BY e.event_name, p.population DESC
);



-- usefull materialized view
CREATE MATERIALIZED VIEW full_taxonomy (class, order_, family, genus, species) AS
  SELECT t1.taxon, t2.taxon, t3.taxon, t4.taxon, t5.taxon
  FROM taxons AS t1
  LEFT OUTER JOIN taxons AS t2 ON t1.taxon_id=t2.taxon_parent
  LEFT OUTER JOIN taxons AS t3 ON t2.taxon_id=t3.taxon_parent
  LEFT OUTER JOIN taxons AS t4 ON t3.taxon_id=t4.taxon_parent
  LEFT OUTER JOIN taxons AS t5 ON t4.taxon_id=t5.taxon_parent
  WHERE t1.taxon_rank = 'class';

-- mat. view check
SELECT * FROM full_taxonomy;
SELECT * FROM full_taxonomy WHERE species = 'notabilis';



-- window function
SELECT e.event_name,
       t.taxon,
       p.population,
       rank() OVER (
         PARTITION BY e.event_name
         ORDER BY t.taxon
       )
  FROM taxons as t
  JOIN populations p on t.taxon_id = p.taxon_id
  JOIN events e on p.event_id = e.event_id
  ORDER BY e.event_name;

--

-- first trigger

DROP TRIGGER IF EXISTS add_event_check ON events;
DROP FUNCTION IF EXISTS add_event_date();

CREATE FUNCTION add_event_date() RETURNS trigger AS
  $$
  BEGIN
    IF (old.event_date is NULL) THEN
        UPDATE events
        SET event_date = current_date
        WHERE event_id = new.event_id;
    END IF;
    RETURN NULL;
  END;
  $$ language plpgsql;

CREATE TRIGGER add_event_check AFTER
  INSERT ON events
  FOR EACH ROW EXECUTE FUNCTION add_event_date();

-- first trigger check
INSERT INTO events (event_name, habitat_id, microhabitat_id, latitude, longitude)
  VALUES ('новое событие', 3, 4, 123, 123);

SELECT * FROM events
  ORDER BY event_id DESC
  LIMIT 5;

DELETE FROM events WHERE event_name = 'новое событие';


--

-- second trigger

DROP TRIGGER IF EXISTS make_user ON users;
DROP FUNCTION IF EXISTS make_user_pro();

CREATE FUNCTION make_user_pro() RETURNS trigger AS
  $$
  BEGIN
    UPDATE users
    SET full_name = (NEW.surname || ' ' || NEW.name_usr || ' ' || NEW.sec_name)
    WHERE user_id = NEW.user_id;
    --WHERE surname = NEW.surname AND name_usr = NEW.name_usr AND sec_name = NEW.sec_name;
    RETURN NULL;
  END;
  $$ language plpgsql;

CREATE TRIGGER make_user AFTER
  INSERT ON users
  FOR EACH ROW EXECUTE FUNCTION make_user_pro();

-- second trigger check
INSERT INTO users (surname, name_usr, sec_name)
  VALUES ('gelvan', 'pavel', 'zin'),
         ('hello', 'kir', 'lul');

SELECT * FROM users
  ORDER BY user_id DESC
  LIMIT 5;

DELETE FROM users WHERE surname = 'hello';

-- before trigger
DROP TRIGGER IF EXISTS person_trigger ON users;
DROP FUNCTION IF EXISTS person_func();

CREATE OR REPLACE FUNCTION person_func()
    RETURNS TRIGGER AS $$
    BEGIN
    IF POSITION(' ' IN NEW.name_usr) > 0 OR
    POSITION(' ' IN NEW.surname) > 0 OR POSITION(' ' IN NEW.sec_name) > 0
    THEN
        RAISE EXCEPTION 'Name, surname and second name must not include white space.';
    END IF;
    RETURN NEW;
    END
    $$ LANGUAGE plpgsql;

CREATE TRIGGER person_trigger BEFORE
  INSERT ON users
  FOR EACH ROW EXECUTE FUNCTION person_func();


-- before trigger check
INSERT INTO users VALUES ('gelvann', 'kirilll ', 'pavlovich');

INSERT INTO users VALUES ('gelvann', 'kirilll', 'paasdsvlovich');

SELECT * FROM users
  ORDER BY users.user_id DESC
  LIMIT 5;

DELETE FROM users WHERE users.user_id > 16;


-- first function
CREATE OR REPLACE FUNCTION count_by_letters()
  RETURNS TABLE( letter char( 1 ), num bigint ) AS
$$
  SELECT substr( taxon, 1, 1 ) AS letter, count( * )
  FROM taxons GROUP BY letter ORDER BY letter;
$$ LANGUAGE SQL;

-- first function execution
SELECT * FROM count_by_letters();


-- second function
CREATE OR REPLACE FUNCTION translate_habitat(in rus_name text,
                                     out eng_name text)
    AS $$
    SELECT habitat_name FROM habitats
      WHERE habitat_name_ru = rus_name;
    $$ language SQL;

-- second function check
SELECT * FROM translate_habitat('болото');
SELECT * FROM translate_habitat('луг');




