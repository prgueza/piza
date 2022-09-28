/* BACKOFFICE SCHEMA */

CREATE SCHEMA IF NOT EXISTS backoffice;

/* TABLES */

-- backoffice.supply_doughs

CREATE TABLE backoffice.supply_doughs (
  dough_id INT NOT NULL REFERENCES delivery_system.doughs(id),
  quantity INT NOT NULL DEFAULT 10
);

COMMENT ON TABLE backoffice.supply_doughs IS 'Determines the quantity of each dough we ask for to our suppliers';
COMMENT ON COLUMN backoffice.supply_doughs.dough_id IS 'Dough ID';
COMMENT ON COLUMN backoffice.supply_doughs.quantity IS 'Ammount of that dough to be supplied';

-- backoffice.supply_ingredients

CREATE TABLE backoffice.supply_ingredients (
  ingredient_id INT NOT NULL REFERENCES delivery_system.ingredients(id),
  quantity INT NOT NULL DEFAULT 12
);

COMMENT ON TABLE backoffice.supply_ingredients IS 'Determines the quantity of each ingredient we ask for to our suppliers';
COMMENT ON COLUMN backoffice.supply_ingredients.ingredient_id IS 'Ingredient ID';
COMMENT ON COLUMN backoffice.supply_ingredients.quantity IS 'Ammount of that ingredient to be supplied';

-- backoffice.runners

CREATE TABLE backoffice.runners (
  runner TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT TRUE
);

COMMENT ON TABLE backoffice.runners IS 'Used to activate/deactivate the runners';
COMMENT ON COLUMN backoffice.runners.runner IS 'Runner ID';
COMMENT ON COLUMN backoffice.runners.active IS 'Determines if the runner is active or not';

/* FUNCTIONS */

CREATE OR REPLACE FUNCTION backoffice.random_between (low INT, high INT) 
  RETURNS INT 
  LANGUAGE plpgsql
AS $function$

  BEGIN

    RETURN FLOOR(RANDOM()* (high - low + 1) + low)::INT;

  END;

$function$;

CREATE OR REPLACE FUNCTION backoffice.place_order()
  RETURNS VOID
  LANGUAGE plpgsql
AS $FUNCTION$

  DECLARE

    _client_id INT;
    _dough_id INT;
    _ingredient_ids INT[];
    _order_id INT;

  BEGIN
        
      -- Select a random client
      SELECT id
      INTO _client_id
      FROM delivery_system.clients
      ORDER BY RANDOM()
      LIMIT 1;
  
      -- Select a random dough
      SELECT id
      INTO _dough_id
      FROM delivery_system.doughs
      ORDER BY RANDOM()
      LIMIT 1;
  
      -- Select between 2 and 6 random ingredients
      WITH ingredients AS (
        SELECT id
        FROM delivery_system.ingredients
        ORDER BY RANDOM()
        LIMIT backoffice.random_between(2, 6)
      ) SELECT ARRAY_AGG(id) INTO _ingredient_ids FROM ingredients;
  
      -- Create the order
      INSERT INTO delivery_system.orders (client_id) 
      VALUES (_client_id)
      RETURNING id INTO _order_id;
  
      -- Insert the ordered dough
      INSERT INTO delivery_system.order_doughs (order_id, dough_id) 
      VALUES (_order_id, _dough_id);
  
      -- Insert the ordered ingredients
      INSERT INTO delivery_system.order_ingredients (order_id, ingredient_id) 
      SELECT _order_id order_id, UNNEST(_ingredient_ids) ingredient_id;

      RAISE NOTICE 'Client with id % just ordered a pizza! (Dough: %; Ingredients: %)', _client_id, _dough_id, ARRAY_TO_STRING(_ingredient_ids, ',');

  END;

$FUNCTION$;

CREATE OR REPLACE PROCEDURE backoffice.place_order_runner()
  LANGUAGE plpgsql
AS $PROCEDURE$

  DECLARE

    _active BOOLEAN := (SELECT active FROM backoffice.runners WHERE runner = 'place_order');
    _interval INT := 2;

  BEGIN

    WHILE _active LOOP

      PERFORM backoffice.place_order();

      COMMIT;

      PERFORM PG_SLEEP(_interval);

      COMMIT;

    END LOOP;

  END;

$PROCEDURE$;

CREATE OR REPLACE FUNCTION backoffice.supply ()
  RETURNS VOID
  LANGUAGE plpgsql
AS $FUNCTION$

  DECLARE
    
    dough_id INT;
    ingredient_id INT;
    quantity INT;

  BEGIN

    RAISE NOTICE 'The supplies truck is here with doughs and ingredients!';

    -- Insert missing doughs up to the quantity set in the supply_doughs configuration
    FOR dough_id, quantity IN 
      SELECT supply.dough_id, GREATEST(supply.quantity - COUNT(stock.*), 0) quantity
      FROM backoffice.supply_doughs supply
      LEFT JOIN delivery_system.stock_doughs stock ON supply.dough_id = stock.dough_id AND stock.pizza_id IS NULL
      GROUP BY supply.dough_id, supply.quantity
    LOOP

      INSERT INTO delivery_system.stock_doughs (dough_id) 
      SELECT dough_id
      FROM GENERATE_SERIES(0, quantity) AS a(n);

      RAISE NOTICE '% doughs with id % supplied!', quantity, dough_id;
    
    END LOOP;

    -- Insert missing ingredients up to the quantity set in the supply_ingredients configuration
    FOR ingredient_id, quantity IN 
      SELECT supply.ingredient_id, GREATEST(supply.quantity - COUNT(stock.*), 0) quantity
      FROM backoffice.supply_ingredients supply
      LEFT JOIN delivery_system.stock_ingredients stock ON supply.ingredient_id = stock.ingredient_id AND stock.pizza_id IS NULL
      GROUP BY supply.ingredient_id, supply.quantity
    LOOP

      INSERT INTO delivery_system.stock_ingredients (ingredient_id) 
      SELECT ingredient_id
      FROM GENERATE_SERIES(0, quantity) AS a(n);

      RAISE NOTICE '% ingredients with id % supplied!', quantity, ingredient_id;
    
    END LOOP;

  END;

$FUNCTION$;

CREATE OR REPLACE PROCEDURE backoffice.supply_runner()
  LANGUAGE plpgsql
AS $PROCEDURE$

  DECLARE

    _active BOOLEAN := (SELECT active FROM backoffice.runners WHERE runner = 'supply');
    _interval INT := 60;

  BEGIN

    WHILE _active LOOP

      PERFORM backoffice.supply();

      COMMIT;

      PERFORM PG_SLEEP(_interval);

      COMMIT;

    END LOOP;

  END;

$PROCEDURE$;

/* DATA */

INSERT INTO backoffice.runners (runner, active) VALUES
  ('supply', TRUE),
  ('place_order', TRUE);

INSERT INTO backoffice.supply_doughs (dough_id, quantity) VALUES
  (1, 10),
  (2, 10),
  (3, 10);

INSERT INTO backoffice.supply_ingredients (ingredient_id, quantity) VALUES
  (1, 12),
  (2, 12),
  (3, 12),
  (4, 12),
  (5, 12),
  (6, 12),
  (7, 12),
  (8, 12),
  (9, 12),
  (10, 12);
