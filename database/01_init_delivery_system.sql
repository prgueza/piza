/* DELIVERY SYSTEM SCHEMA */

CREATE SCHEMA IF NOT EXISTS delivery_system;

/* USERS */

CREATE ROLE delivery NOLOGIN;
CREATE ROLE authenticator NOINHERIT LOGIN PASSWORD 'wewantpizza';
GRANT delivery TO authenticator;

/* TABLES */

-- delivery_system.clients

CREATE TABLE IF NOT EXISTS delivery_system.clients (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL,
  surname TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT NOT NULL,
  avatar_url TEXT NOT NULL
);

COMMENT ON TABLE delivery_system.clients IS 'Holds information about our beloved clients';
COMMENT ON COLUMN delivery_system.clients.id IS 'Client ID';
COMMENT ON COLUMN delivery_system.clients.name IS 'Client name';
COMMENT ON COLUMN delivery_system.clients.surname IS 'Client surname';
COMMENT ON COLUMN delivery_system.clients.email IS 'Client email address';
COMMENT ON COLUMN delivery_system.clients.phone IS 'Client phone number';
COMMENT ON COLUMN delivery_system.clients.avatar_url IS 'Client avatar url';

-- delivery_system.pizzas

CREATE TABLE delivery_system.pizzas (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE delivery_system.pizzas IS 'List of pizzas made and delivered by us';
COMMENT ON COLUMN delivery_system.pizzas.id IS 'Pizza ID';
COMMENT ON COLUMN delivery_system.pizzas.created_at IS 'Time at which the pizza was made';

-- delivery_system.doughs

CREATE TABLE delivery_system.doughs (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL
);

COMMENT ON TABLE delivery_system.doughs IS 'List of available doughs for our clients to pick from';
COMMENT ON COLUMN delivery_system.doughs.id IS 'Dough ID';
COMMENT ON COLUMN delivery_system.doughs.name IS 'Dough name';
COMMENT ON COLUMN delivery_system.doughs.description IS 'Description of the dough';

-- delivery_system.ingredients

CREATE TABLE delivery_system.ingredients (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL
);

COMMENT ON TABLE delivery_system.ingredients IS 'List of available ingredients for our clients to pick from';
COMMENT ON COLUMN delivery_system.ingredients.id IS 'Ingredient ID';
COMMENT ON COLUMN delivery_system.ingredients.name IS 'Ingredient name';
COMMENT ON COLUMN delivery_system.ingredients.description IS 'Description of the ingredient';

-- delivery_system.stock_ingredients

CREATE TABLE delivery_system.stock_ingredients (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  ingredient_id INT NOT NULL REFERENCES delivery_system.ingredients(id),
  pizza_id INT REFERENCES delivery_system.pizzas(id)
);

COMMENT ON TABLE delivery_system.stock_ingredients IS 'List of ingredients in stock for our cooks to use in ordered pizzas';
COMMENT ON COLUMN delivery_system.stock_ingredients.id IS 'Stock ID';
COMMENT ON COLUMN delivery_system.stock_ingredients.ingredient_id IS 'Ingredient ID for this stock item';
COMMENT ON COLUMN delivery_system.stock_ingredients.pizza_id IS 'Pizza ID where the ingredient was used (if NULL this ingredient has not been used yet)';

-- delivery_system.stock_doughs

CREATE TABLE delivery_system.stock_doughs (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  dough_id INT NOT NULL REFERENCES delivery_system.doughs(id),
  pizza_id INT REFERENCES delivery_system.pizzas(id)
);

COMMENT ON TABLE delivery_system.stock_doughs IS 'List of doughs in stock for our cooks to use in ordered pizzas';
COMMENT ON COLUMN delivery_system.stock_doughs.id IS 'Stock ID';
COMMENT ON COLUMN delivery_system.stock_doughs.dough_id IS 'Dough ID for this stock item';
COMMENT ON COLUMN delivery_system.stock_doughs.pizza_id IS 'Pizza ID where the dough was used (if NULL this dough has not been used yet)';

-- delivery_system.orders

CREATE TYPE delivery_system.delivery_status AS ENUM ('delivered', 'not delivered');

COMMENT ON TYPE delivery_system.delivery_status IS 'Options for the delivery_status column (delivered / not delivered)';

CREATE TABLE delivery_system.orders (
  id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  client_id INT NOT NULL REFERENCES delivery_system.clients(id),
  pizza_id INT REFERENCES delivery_system.pizzas(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  dispatched_at TIMESTAMPTZ,
  delivery_status delivery_system.delivery_status
);

COMMENT ON TABLE delivery_system.orders IS 'List of orders';
COMMENT ON COLUMN delivery_system.orders.id IS 'Order ID';
COMMENT ON COLUMN delivery_system.orders.client_id IS 'Client ID that reflects who ordered this pizza';
COMMENT ON COLUMN delivery_system.orders.pizza_id IS 'Pizza ID that refelcts which pizza was delivered to the client (if no pizza was delivered, or has not been delivered yet, this field is NULL)';
COMMENT ON COLUMN delivery_system.orders.created_at IS 'Time at which the order was placed';
COMMENT ON COLUMN delivery_system.orders.dispatched_at IS 'Time at which the order was dispatched, either delivered or not delivered (this field updates automatically when the delivery_status changes)';
COMMENT ON COLUMN delivery_system.orders.delivery_status IS 'Final status of the order (delivered or not delivered)';

CREATE OR REPLACE FUNCTION delivery_system.fn_handle_dispatch()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $function$
  BEGIN
    
    IF OLD.delivery_status IS NOT NULL THEN

      NEW.dispatched_at := NOW();
    
    ELSE
    
      NEW.dispatched_at := NULL;
    
    END IF;

    RETURN NEW;

  END;
$function$;

COMMENT ON FUNCTION delivery_system.fn_handle_dispatch IS 'Updates the dispatched_at column in the orders table when the status changes';

CREATE OR REPLACE TRIGGER tr_on_dispatch BEFORE UPDATE 
  OF delivery_status
  ON delivery_system.orders FOR EACH ROW 
  EXECUTE FUNCTION delivery_system.fn_handle_dispatch();

COMMENT ON TRIGGER tr_on_dispatch ON delivery_system.orders IS 'Used for updating the dispatched_at column in response to a change in its delivery_status';

-- delivery_system.order_doughs

CREATE TABLE delivery_system.order_doughs (
  order_id INT NOT NULL REFERENCES delivery_system.orders(id),
  dough_id INT NOT NULL REFERENCES delivery_system.doughs(id)
);

COMMENT ON TABLE delivery_system.order_doughs IS 'Relation table between the order and the dough ordered';
COMMENT ON COLUMN delivery_system.order_doughs.order_id IS 'Order ID';
COMMENT ON COLUMN delivery_system.order_doughs.dough_id IS 'Dough ID';

-- delivery_system.order_ingredients

CREATE TABLE delivery_system.order_ingredients (
  order_id INT NOT NULL REFERENCES delivery_system.orders(id),
  ingredient_id INT NOT NULL REFERENCES delivery_system.ingredients(id)
);

COMMENT ON TABLE delivery_system.order_ingredients IS 'Relation table between the order and the ingredients ordered';
COMMENT ON COLUMN delivery_system.order_ingredients.order_id IS 'Stock ID';
COMMENT ON COLUMN delivery_system.order_ingredients.ingredient_id IS 'Ingredient ID';

/* PERMISSIONS */

GRANT usage ON SCHEMA delivery_system TO delivery;

GRANT SELECT ON delivery_system.clients TO delivery;
GRANT SELECT ON delivery_system.doughs TO delivery;
GRANT SELECT ON delivery_system.ingredients TO delivery;
GRANT SELECT ON delivery_system.stock_doughs TO delivery;
GRANT SELECT ON delivery_system.stock_ingredients TO delivery;
GRANT SELECT, UPDATE, INSERT ON delivery_system.pizzas TO delivery;
GRANT SELECT, UPDATE ON delivery_system.orders TO delivery;
GRANT SELECT ON delivery_system.order_doughs TO delivery;
GRANT SELECT ON delivery_system.order_ingredients TO delivery;

/* DATA */

INSERT INTO delivery_system.clients ("name", surname, email, phone, avatar_url) VALUES
  ('Proud', 'Owner', 'owner@piza.com', '563-340-3352', 'https://images.unsplash.com/photo-1597223557154-721c1cecc4b0?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=240&q=80'),
  ('Scott', 'Bruce', 's.bruce@piza.clients.com', '267-288-6798', 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=240&q=80'),
  ('Betty', 'Morrison', 'b.morrison@piza.clients.com', '253-266-4348', 'https://images.unsplash.com/photo-1479936343636-73cdc5aae0c3?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=240&q=80'),
  ('James', 'Wentworth', 'j.wentworth@piza.clients.com', '616-536-9234', 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=240&q=80'),
  ('Bernice', 'Fields', 'b.fields@piza.clients.com', '406-246-9699', 'https://images.unsplash.com/photo-1519699047748-de8e457a634e?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=240&q=80'),
  ('Christopher', 'Bucklin', 'c.bucklin@piza.clients.com', '662-756-4685', 'https://images.unsplash.com/photo-1542909168-82c3e7fdca5c?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=240&q=80');

INSERT INTO delivery_system.doughs ("name", "description") VALUES
  ('Thin', 'Paperlike dough. In fact, dough? what dough?'),
  ('Crusty', 'Provides the best chewing sounds you will ever hear'),
  ('Cheesy', 'Not enough cheese? Try this');

INSERT INTO delivery_system.ingredients ("name", "description") VALUES
  ('Bacon', 'Good ol bacon for your pizza'),
  ('Beef', 'Some cattle meat for you to enjoy'),
  ('Chicken pops', 'Breaded and fried tasty chicken'),
  ('Pepperoni', 'Sounds like pepper but not even close. Much better in fact'),
  ('Tuna', 'Eww'),
  ('Pineapple', 'Bring some controversy to the table'),
  ('Mushrooms', 'Turn your pizza into a salad'),
  ('Tomato', 'Tomato? Really?'),
  ('Extra cheese', 'Cheese is never enough'),
  ('Onion', ':_(');