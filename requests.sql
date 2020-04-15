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
